// GET /functions/v1/space-weather
// Today's space weather from NASA DONKI (solar flares and coronal mass ejections over the
// last 3 days), cached in public.space_weather for an hour. The game uses it for the
// "real storm today" banner and to seed storm levels with real events.
import { admin } from "../_shared/admin.ts";
import { handler, json } from "../_shared/http.ts";

// NASA's direct public API moved on September 30, 2026. The api.nasa.gov
// gateway currently returns upstream 503s; the direct endpoint needs no key.
// https://ccmc.gsfc.nasa.gov/news/major-updates/
const DONKI = "https://ccmc.gsfc.nasa.gov/DONKI-API/get";
const CACHE_MINUTES = 60;

type Flare = { classType?: string; beginTime?: string };
type Cme = { speed?: number; time21_5?: string };

function day(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** "X1.2" > "M5.0" > "C3.1": compare flare classes. */
function flareRank(c: string | undefined): number {
  if (!c) return 0;
  const scale: Record<string, number> = { A: 1, B: 10, C: 100, M: 1000, X: 10000 };
  return (scale[c[0]] ?? 0) * (parseFloat(c.slice(1)) || 1);
}

async function donki<T>(path: string, params: Record<string, string>): Promise<T[]> {
  const url = `${DONKI}/${path}?${new URLSearchParams(params)}`;
  const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) throw new Error(`DONKI ${path} ${res.status}`);
  const text = await res.text();
  const data: unknown = text.trim() ? JSON.parse(text) : [];
  if (!Array.isArray(data)) throw new Error(`DONKI ${path} returned an invalid response`);
  return data as T[];
}

Deno.serve(handler(async (_req) => {
  const db = admin();
  const today = day(new Date());
  const { data: cached } = await db.from("space_weather").select("*").eq("day", today).maybeSingle();
  if (cached && Date.now() - Date.parse(cached.fetched_at) < CACHE_MINUTES * 60_000) {
    return json({ ...cached, raw: undefined, cached: true });
  }

  const start = day(new Date(Date.now() - 3 * 86_400_000));
  try {
    const [flares, cmes] = await Promise.all([
      donki<Flare>("FLR", { startDate: start, endDate: today }),
      donki<Cme>("CMEAnalysis", { startDate: start, endDate: today, mostAccurateOnly: "true", speed: "0", halfAngle: "0" }),
    ]);
    const strongest = flares.map((f) => f.classType).filter(Boolean).sort((a, b) => flareRank(b) - flareRank(a))[0] ?? null;
    const fastest = Math.max(0, ...cmes.map((c) => c.speed ?? 0));
    const level = (strongest?.startsWith("X") || fastest >= 1000) ? "storm"
      : (strongest?.startsWith("M") || fastest >= 500) ? "watch" : "calm";
    const summary = level === "storm"
      ? `Solar storm: ${strongest ?? "fast CME"}${fastest ? `, CME at ${Math.round(fastest)} km/s` : ""}. Astronauts would shelter.`
      : level === "watch"
      ? `Watch: ${strongest ? `${strongest} flare` : `CME at ${Math.round(fastest)} km/s`} in the last 3 days.`
      : "Calm Sun: no strong flares or fast CMEs in the last 3 days.";
    const row = {
      day: today, level, flares: flares.length, cmes: cmes.length, strongest, summary,
      raw: { flares: flares.slice(0, 20), cmes: cmes.slice(0, 20) }, fetched_at: new Date().toISOString(),
    };
    const { error } = await db.from("space_weather").upsert(row);
    if (error) console.error(error);
    return json({ ...row, raw: undefined, cached: false });
  } catch (e) {
    console.error("DONKI unavailable", e);
    if (cached) return json({ ...cached, raw: undefined, cached: true, stale: true });
    return json({ day: today, level: "calm", flares: 0, cmes: 0, strongest: null,
      summary: "NASA space weather is not reachable right now.", unavailable: true });
  }
}));

// GET /functions/v1/class-report?class_id=<uuid>
// A CSV of the class for the teacher: progress, Readiness Check before/after and
// the six skills. Runs as the teacher (their Supabase JWT), so RLS decides what is visible.
import { createClient } from "@supabase/supabase-js";
import { requireUserId } from "../_shared/auth.ts";
import { cors, handler, HttpError, requireEnv } from "../_shared/http.ts";

const SKILLS = ["prioritise", "systems", "root_cause", "resource_math", "procedure", "teamwork"];

function cell(v: unknown): string {
  const s = v === null || v === undefined ? "" : String(v);
  // Quote everything and neutralise spreadsheet formulas
  const safe = /^[=+\-@]/.test(s) ? `'${s}` : s;
  return `"${safe.replace(/"/g, '""')}"`;
}

Deno.serve(handler(async (req) => {
  await requireUserId(req); // rejects missing or expired tokens early
  const classId = new URL(req.url).searchParams.get("class_id") ?? "";
  if (!/^[0-9a-f-]{36}$/.test(classId)) throw new HttpError(400, "Bad class id");
  const db = createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: req.headers.get("Authorization")! } },
    auth: { persistSession: false },
  });

  const { data: klass, error: cErr } = await db.from("classes").select("name, age_mode").eq("id", classId).maybeSingle();
  if (cErr) throw cErr;
  if (!klass) throw new HttpError(403, "Not your class");
  const { data: students, error: sErr } = await db.rpc("class_students", { cid: classId });
  if (sErr) throw new HttpError(403, sErr.message);
  const ids = (students ?? []).map((s: { student_id: string }) => s.student_id);
  const { data: mastery } = ids.length
    ? await db.from("skill_mastery").select("user_id, skill, score").in("user_id", ids)
    : { data: [] };
  const score = new Map<string, number>();
  for (const m of mastery ?? []) score.set(`${m.user_id}:${m.skill}`, m.score);

  const header = ["Name", "Username", "Levels done", "Stars", "Current level", "Before %", "After %", "Gain",
    ...SKILLS.map((s) => `Skill: ${s.replace("_", " ")}`), "Last active", "Needs help", "Reason"];
  const rows = (students ?? []).map((s: Record<string, unknown>) => [
    s.display_name, s.username, s.levels_done, s.stars, s.current_level, s.pre_score, s.post_score,
    s.pre_score != null && s.post_score != null ? Number(s.post_score) - Number(s.pre_score) : "",
    ...SKILLS.map((k) => score.get(`${s.student_id}:${k}`) ?? ""),
    s.last_active ? String(s.last_active).slice(0, 16).replace("T", " ") : "never",
    s.needs_help ? "yes" : "no", s.help_reason ?? "",
  ]);
  const csv = [header, ...rows].map((r) => r.map(cell).join(",")).join("\r\n");
  const file = `${klass.name.replace(/[^A-Za-z0-9 _-]/g, "").trim() || "class"} - Shackleton Station.csv`;
  return new Response("﻿" + csv, {
    headers: { ...cors, "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": `attachment; filename="${file}"` },
  });
}));

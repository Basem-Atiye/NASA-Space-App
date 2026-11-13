// Verifies the Supabase Auth JWT the app sends as "Authorization: Bearer <token>"
// and returns the user id. Edge Functions may run with verify_jwt = false and
// rely on this helper instead.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { HttpError, requireEnv } from "./http.ts";

export async function requireUserId(req: Request): Promise<string> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) throw new HttpError(401, "Sign in first");

  const url = requireEnv("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY") || "";
  if (!anon) throw new HttpError(500, "Auth is not configured on the server.");

  const supabase = createClient(url, anon, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user?.id) throw new HttpError(401, "Your session has expired. Sign in again.");
  return data.user.id;
}

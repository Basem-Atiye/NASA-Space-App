// Supabase client with the service role (bypasses RLS). Only ever used inside
// Edge Functions; the key is provided by Supabase as SUPABASE_SERVICE_ROLE_KEY.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { HttpError, requireEnv } from "./http.ts";

let client: SupabaseClient | null = null;

export function admin(): SupabaseClient {
  client ??= createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return client;
}

/** The caller must be a teacher and must own the class. */
export async function requireTeacherOfClass(userId: string, classId: string): Promise<{ id: string; name: string; age_mode: string }> {
  if (!/^[0-9a-f-]{36}$/.test(classId)) throw new HttpError(400, "Bad class id");
  const { data, error } = await admin()
    .from("classes")
    .select("id, name, age_mode, teacher_id")
    .eq("id", classId)
    .maybeSingle();
  if (error) throw error;
  if (!data || data.teacher_id !== userId) throw new HttpError(403, "Not your class");
  return data;
}

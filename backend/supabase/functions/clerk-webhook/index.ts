// Legacy Clerk webhook endpoint — disabled. Profiles are created by ensure_profile
// / create-students under Supabase Auth. Kept so old Dashboard webhooks return 410.
import { handler, HttpError } from "../_shared/http.ts";

Deno.serve(handler(async () => {
  throw new HttpError(410, "Clerk webhooks are retired. Use Supabase Auth.");
}));

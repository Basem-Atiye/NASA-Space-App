// POST /functions/v1/clerk-webhook   (Clerk Dashboard > Webhooks, events: user.updated, user.deleted)
// Keeps profiles in step with Clerk. Signed by Svix; the secret is CLERK_WEBHOOK_SIGNING_SECRET.
import { Webhook } from "svix";
import { admin } from "../_shared/admin.ts";
import { handler, HttpError, json, requireEnv } from "../_shared/http.ts";

type ClerkEvent = {
  type: string;
  data: { id?: string; first_name?: string | null; username?: string | null; deleted?: boolean };
};

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "Use POST");
  const payload = await req.text();
  let event: ClerkEvent;
  try {
    // Throws if the signature or timestamp is wrong
    new Webhook(requireEnv("CLERK_WEBHOOK_SIGNING_SECRET")).verify(payload, {
      "svix-id": req.headers.get("svix-id") ?? "",
      "svix-timestamp": req.headers.get("svix-timestamp") ?? "",
      "svix-signature": req.headers.get("svix-signature") ?? "",
    });
    event = JSON.parse(payload) as ClerkEvent;
  } catch (_) {
    throw new HttpError(400, "Bad signature");
  }
  const id = event.data.id;
  if (!id) return json({ ignored: true });
  const db = admin();

  switch (event.type) {
    case "user.deleted": {
      // Cascades to every row the user owns (attempts, skills, memberships, nudges...)
      const { error } = await db.from("profiles").delete().eq("id", id);
      if (error) throw error;
      return json({ deleted: id });
    }
    case "user.updated": {
      const name = (event.data.first_name ?? "").trim();
      if (name.length >= 2 && name.length <= 24) {
        const { error } = await db.from("profiles").update({ display_name: name }).eq("id", id);
        if (error) throw error;
      }
      return json({ updated: id });
    }
    default:
      return json({ ignored: event.type });
  }
}));

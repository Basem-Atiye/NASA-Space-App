// POST /functions/v1/create-students
// The teacher manages student accounts for one class. Body:
//   { "action": "create",   "class_id": "<uuid>", "names": ["Rana", "Omar"] }
//   { "action": "reset_pin", "class_id": "<uuid>", "student_id": "user_..." }
//   { "action": "remove",    "class_id": "<uuid>", "student_id": "user_..." }
// "create" returns printable cards: [{ name, username, pin, student_id }].
// PINs are shown once and never stored by us; a lost PIN is reset, not looked up.
import { createClerkClient } from "@clerk/backend";
import { admin, requireTeacherOfClass } from "../_shared/admin.ts";
import { clerkUserId } from "../_shared/auth.ts";
import { handler, HttpError, json, requireEnv } from "../_shared/http.ts";
import { cleanName, newPin, newUsername, studentPassword } from "../_shared/students.ts";

const MAX_PER_CALL = 40;

type Card = { name: string; username: string; pin: string; student_id: string };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "Use POST");
  const teacherId = await clerkUserId(req);
  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? "create");
  const klass = await requireTeacherOfClass(teacherId, String(body.class_id ?? ""));
  const clerk = createClerkClient({ secretKey: requireEnv("CLERK_SECRET_KEY") });
  const db = admin();

  if (action === "create") {
    const raw: unknown[] = Array.isArray(body.names) ? body.names : [];
    if (raw.length === 0) throw new HttpError(400, "Add at least one first name");
    if (raw.length > MAX_PER_CALL) throw new HttpError(400, `At most ${MAX_PER_CALL} students at a time`);
    const cards: Card[] = [];
    const failed: { name: string; reason: string }[] = [];
    for (const r of raw) {
      const name = cleanName(r);
      if (!name) {
        failed.push({ name: String(r ?? ""), reason: "Use a first name of 2 to 24 letters" });
        continue;
      }
      let created = false;
      for (let tries = 0; tries < 3 && !created; tries++) {
        const username = newUsername(name);
        const pin = newPin();
        try {
          const user = await clerk.users.createUser({
            username,
            password: studentPassword(username, pin),
            firstName: name,
            skipPasswordChecks: true,
            skipLegalChecks: true,
            publicMetadata: { role: "student", created_by: teacherId },
          });
          const { error: pErr } = await db.from("profiles").insert({
            id: user.id, role: "student", display_name: name, username, created_by: teacherId,
            age_mode: klass.age_mode,
          });
          if (pErr) {
            await clerk.users.deleteUser(user.id).catch(() => {});
            throw pErr;
          }
          const { error: mErr } = await db.from("class_members").insert({ class_id: klass.id, student_id: user.id });
          if (mErr) throw mErr;
          cards.push({ name, username, pin, student_id: user.id });
          created = true;
        } catch (e) {
          const msg = (e as { errors?: { code?: string }[] }).errors?.[0]?.code ?? "";
          if (msg === "form_identifier_exists") continue; // username taken: try another
          console.error("create student failed", e);
          failed.push({ name, reason: "Could not create this account" });
          break;
        }
      }
    }
    return json({ class: { id: klass.id, name: klass.name, age_mode: klass.age_mode }, cards, failed });
  }

  const studentId = String(body.student_id ?? "");
  const { data: member } = await db.from("class_members").select("student_id")
    .eq("class_id", klass.id).eq("student_id", studentId).maybeSingle();
  const { data: profile } = await db.from("profiles").select("id, username, display_name, created_by")
    .eq("id", studentId).maybeSingle();
  if (!member || !profile) throw new HttpError(404, "Student not in this class");

  if (action === "reset_pin") {
    if (!profile.username || profile.created_by !== teacherId) {
      throw new HttpError(403, "Only accounts you created can get a new PIN");
    }
    const pin = newPin();
    await clerk.users.updateUser(studentId, {
      password: studentPassword(profile.username, pin),
      skipPasswordChecks: true,
      signOutOfOtherSessions: true,
    });
    return json({ card: { name: profile.display_name, username: profile.username, pin, student_id: studentId } });
  }

  if (action === "remove") {
    // Accounts this teacher created are deleted entirely (Clerk webhook removes the data);
    // anyone who joined with a code is just taken out of the class.
    if (profile.created_by === teacherId) {
      await clerk.users.deleteUser(studentId);
      await db.from("profiles").delete().eq("id", studentId);
      return json({ removed: studentId, deleted_account: true });
    }
    await db.from("class_members").delete().eq("class_id", klass.id).eq("student_id", studentId);
    return json({ removed: studentId, deleted_account: false });
  }

  throw new HttpError(400, "Unknown action");
}));

// POST /functions/v1/create-students
// Teacher-managed student accounts for one class. Body:
//   { "action": "create",   "class_id": "<uuid>", "names": ["Rana", "Omar"] }
//   { "action": "reset_pin", "class_id": "<uuid>", "student_id": "<uuid>" }
//   { "action": "remove",    "class_id": "<uuid>", "student_id": "<uuid>" }
// "create" returns printable cards: [{ name, username, pin, student_id }].
import { admin, requireTeacherOfClass } from "../_shared/admin.ts";
import { requireUserId } from "../_shared/auth.ts";
import { handler, HttpError, json } from "../_shared/http.ts";
import { cleanName, newPin, newUsername, studentEmail, studentPassword } from "../_shared/students.ts";

const MAX_PER_CALL = 40;

type Card = { name: string; username: string; pin: string; student_id: string };

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new HttpError(405, "Use POST");
  const teacherId = await requireUserId(req);
  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? "create");
  const klass = await requireTeacherOfClass(teacherId, String(body.class_id ?? ""));
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
        const email = studentEmail(username);
        try {
          const { data: createdUser, error: authErr } = await db.auth.admin.createUser({
            email,
            password: studentPassword(username, pin),
            email_confirm: true,
            user_metadata: {
              role_intent: "student",
              display_name: name,
              username,
              created_by: teacherId,
            },
          });
          if (authErr || !createdUser.user) throw authErr ?? new Error("create failed");
          const userId = createdUser.user.id;
          const { error: pErr } = await db.from("profiles").insert({
            id: userId,
            role: "student",
            display_name: name,
            username,
            created_by: teacherId,
            age_mode: klass.age_mode,
          });
          if (pErr) {
            await db.auth.admin.deleteUser(userId).catch(() => {});
            throw pErr;
          }
          const { error: mErr } = await db.from("class_members").insert({
            class_id: klass.id,
            student_id: userId,
          });
          if (mErr) throw mErr;
          cards.push({ name, username, pin, student_id: userId });
          created = true;
        } catch (e) {
          const msg = String((e as { message?: string })?.message ?? e).toLowerCase();
          if (msg.includes("already") || msg.includes("exists") || msg.includes("unique")) continue;
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
    const { error } = await db.auth.admin.updateUserById(studentId, {
      password: studentPassword(profile.username, pin),
    });
    if (error) throw error;
    return json({ card: { name: profile.display_name, username: profile.username, pin, student_id: studentId } });
  }

  if (action === "remove") {
    if (profile.created_by === teacherId) {
      await db.auth.admin.deleteUser(studentId).catch(() => {});
      await db.from("profiles").delete().eq("id", studentId);
      return json({ removed: studentId, deleted_account: true });
    }
    await db.from("class_members").delete().eq("class_id", klass.id).eq("student_id", studentId);
    return json({ removed: studentId, deleted_account: false });
  }

  throw new HttpError(400, "Unknown action");
}));

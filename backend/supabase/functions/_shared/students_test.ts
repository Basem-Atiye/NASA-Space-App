import { cleanName, newPin, newUsername, studentPassword } from "./students.ts";
import { Webhook } from "svix";

function assert(c: boolean, m: string) { if (!c) throw new Error(m); }

Deno.test("usernames are lowercase, unique-ish and Clerk-safe", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 500; i++) {
    const u = newUsername("Rána-Lou");
    assert(/^[a-z0-9]{2,12}_[a-z0-9]{6}$/.test(u), u);
    seen.add(u);
  }
  assert(seen.size === 500, "collisions");
  assert(newUsername("李").startsWith("cadet_"), "non-latin names fall back");
});

Deno.test("PINs are 4 digits and passwords are at least 8 characters", () => {
  for (let i = 0; i < 200; i++) assert(/^\d{4}$/.test(newPin()), "pin");
  assert(studentPassword("ab_xxxxxx", "0007") === "ShStn-0007-ab_xxxxxx", "derivation must match the app");
});

Deno.test("names: first names only", () => {
  assert(cleanName("  Rana  ") === "Rana", "trim");
  assert(cleanName("Jean-Luc") === "Jean-Luc", "hyphen");
  assert(cleanName("x") === null, "too short");
  assert(cleanName("<script>") === null, "markup");
  assert(cleanName("rana@mail.com") === null, "no emails");
});

Deno.test("webhook signatures are checked", () => {
  const secret = "whsec_" + btoa("0123456789abcdef0123456789abcdef");
  const wh = new Webhook(secret);
  const body = JSON.stringify({ type: "user.deleted", data: { id: "user_1" } });
  const ts = new Date();
  const sig = wh.sign("msg_1", ts, body);
  const headers = { "svix-id": "msg_1", "svix-timestamp": String(Math.floor(ts.getTime() / 1000)), "svix-signature": sig };
  wh.verify(body, headers);
  let threw = false;
  try { wh.verify(body.replace("user_1", "user_2"), headers); } catch { threw = true; }
  assert(threw, "tampered body must fail");
});

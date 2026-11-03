// Student accounts made by teachers: a username and a 4-digit PIN on a printed card.
// Children never type an email. The Clerk password is derived from the PIN and the
// username, and the app derives it the same way (lib/services/auth_service.dart).

export function studentPassword(username: string, pin: string): string {
  return `ShStn-${pin}-${username}`;
}

export function newPin(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 10000;
  return n.toString().padStart(4, "0");
}

const alphabet = "abcdefghjkmnpqrstuvwxyz23456789";

export function newUsername(firstName: string): string {
  const base = firstName
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "")
    .slice(0, 12) || "cadet";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  const tail = Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
  return `${base.length < 2 ? base + "x" : base}_${tail}`;
}

/** First names only, 2–24 characters, letters, spaces, hyphens and apostrophes. */
export function cleanName(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const name = raw.replace(/\s+/g, " ").trim();
  if (name.length < 2 || name.length > 24) return null;
  if (!/^[\p{L}][\p{L}\p{M} '\-]*$/u.test(name)) return null;
  return name;
}

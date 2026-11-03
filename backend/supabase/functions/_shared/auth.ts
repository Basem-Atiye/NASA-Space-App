// Verifies the Clerk session token the app sends as "Authorization: Bearer <token>"
// and gives back the Clerk user id. Supabase's own gateway check is off for these
// functions (verify_jwt = false) because the token is issued by Clerk.
import { verifyToken } from "@clerk/backend";
import { HttpError, requireEnv } from "./http.ts";

export async function clerkUserId(req: Request): Promise<string> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token) throw new HttpError(401, "Sign in first");
  try {
    const payload = await verifyToken(token, {
      secretKey: requireEnv("CLERK_SECRET_KEY"),
      // Optional: the PEM public key makes verification networkless
      jwtKey: Deno.env.get("CLERK_JWT_KEY") || undefined,
    });
    if (!payload.sub) throw new Error("no sub");
    return payload.sub;
  } catch (_) {
    throw new HttpError(401, "Your session has expired. Sign in again.");
  }
}

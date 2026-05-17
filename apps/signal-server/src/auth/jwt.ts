import { jwtVerify } from "jose";
import { config } from "../config.js";

let secretKey: Uint8Array | null = null;

function getSecret(): Uint8Array {
  if (!secretKey) {
    secretKey = new TextEncoder().encode(config.supabaseJwtSecret);
  }
  return secretKey;
}

export async function verifyJwt(
  token: string
): Promise<{ sub: string; email?: string } | null> {
  if (!config.supabaseJwtSecret) return null;
  try {
    const { payload } = await jwtVerify(token, getSecret());
    const sub = payload.sub;
    if (typeof sub !== "string") return null;
    return { sub, email: payload.email as string | undefined };
  } catch {
    return null;
  }
}

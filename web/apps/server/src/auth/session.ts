import { createHash, randomBytes } from "node:crypto";
import { and, eq, gt } from "drizzle-orm";
import type { FastifyReply } from "fastify";
import { db } from "../db/client.js";
import { sessions } from "../db/schema.js";
import { env } from "../config/env.js";

export const sessionCookieName = "craftpresence_session";

export function hashSecret(secret: string, pepper = env.SESSION_SECRET) {
  return createHash("sha256").update(`${pepper}:${secret}`).digest("hex");
}

export async function createSession(reply: FastifyReply, userId: string) {
  const token = randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
  await db.insert(sessions).values({ userId, tokenHash: hashSecret(token), expiresAt });
  reply.setCookie(sessionCookieName, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: env.COOKIE_SECURE,
    path: "/",
    expires: expiresAt
  });
}

export async function deleteSession(reply: FastifyReply, token?: string) {
  if (token) await db.delete(sessions).where(eq(sessions.tokenHash, hashSecret(token)));
  reply.clearCookie(sessionCookieName, { path: "/" });
}

export async function findSessionUserId(token?: string) {
  if (!token) return undefined;
  const [session] = await db
    .select()
    .from(sessions)
    .where(and(eq(sessions.tokenHash, hashSecret(token)), gt(sessions.expiresAt, new Date())))
    .limit(1);
  return session?.userId;
}

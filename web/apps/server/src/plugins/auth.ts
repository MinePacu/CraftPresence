import { eq } from "drizzle-orm";
import type { FastifyInstance, FastifyRequest } from "fastify";
import { db } from "../db/client.js";
import { users } from "../db/schema.js";
import { findSessionUserId } from "../auth/session.js";

export type CurrentUser = {
  id: string;
  email: string;
  displayName: string;
  role: "admin" | "user";
  createdAt: Date;
  updatedAt: Date;
};

declare module "fastify" {
  interface FastifyRequest {
    currentUser?: CurrentUser;
  }
}

export async function authPlugin(app: FastifyInstance) {
  app.addHook("preHandler", async (request) => {
    const userId = await findSessionUserId(request.cookies.craftpresence_session);
    if (!userId) return;
    const [user] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
    if (user) request.currentUser = omitPassword(user);
  });
}

export function requireCurrentUser(request: FastifyRequest): CurrentUser {
  if (!request.currentUser) {
    const error = new Error("Authentication required");
    (error as Error & { statusCode: number }).statusCode = 401;
    throw error;
  }
  return request.currentUser;
}

export function omitPassword(user: typeof users.$inferSelect): CurrentUser {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    role: user.role,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  };
}

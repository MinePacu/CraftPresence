import { eq, sql } from "drizzle-orm";
import type { FastifyInstance } from "fastify";
import { loginInputSchema, setupInputSchema } from "@craftpresence/shared";
import { db } from "../db/client.js";
import { users } from "../db/schema.js";
import { hashPassword, verifyPassword } from "./password.js";
import { createSession, deleteSession, sessionCookieName } from "./session.js";
import { omitPassword, requireCurrentUser } from "../plugins/auth.js";
import { recordAuditEvent } from "../audit/auditService.js";

export async function authRoutes(app: FastifyInstance) {
  app.get("/api/setup/status", async () => {
    const [{ count }] = await db.select({ count: sql<number>`count(*)::int` }).from(users);
    return { requiresSetup: count === 0 };
  });

  app.post("/api/setup", async (request, reply) => {
    const input = setupInputSchema.parse(request.body);
    const [{ count }] = await db.select({ count: sql<number>`count(*)::int` }).from(users);
    if (count > 0) return reply.status(409).send({ message: "Setup has already been completed" });
    const [user] = await db
      .insert(users)
      .values({
        displayName: input.displayName,
        email: input.email.toLowerCase(),
        passwordHash: await hashPassword(input.password),
        role: "admin"
      })
      .returning();
    await createSession(reply, user.id);
    await recordAuditEvent({ actorUserId: user.id, action: "setup.create_admin", entityType: "user", entityId: user.id });
    return { user: omitPassword(user) };
  });

  app.post("/api/auth/login", async (request, reply) => {
    const input = loginInputSchema.parse(request.body);
    const [user] = await db.select().from(users).where(eq(users.email, input.email.toLowerCase())).limit(1);
    if (!user || !(await verifyPassword(user.passwordHash, input.password))) {
      return reply.status(401).send({ message: "Invalid email or password" });
    }
    await createSession(reply, user.id);
    await recordAuditEvent({ actorUserId: user.id, action: "auth.login", entityType: "user", entityId: user.id });
    return { user: omitPassword(user) };
  });

  app.post("/api/auth/logout", async (request, reply) => {
    await recordAuditEvent({ actorUserId: request.currentUser?.id, action: "auth.logout", entityType: "user", entityId: request.currentUser?.id });
    await deleteSession(reply, request.cookies[sessionCookieName]);
    return { ok: true };
  });

  app.get("/api/me", async (request) => {
    const user = requireCurrentUser(request);
    return { user };
  });
}

import type { FastifyInstance } from "fastify";
import { requireCurrentUser } from "../plugins/auth.js";

export async function userRoutes(app: FastifyInstance) {
  app.get("/api/users/me", async (request) => ({ user: requireCurrentUser(request) }));
}

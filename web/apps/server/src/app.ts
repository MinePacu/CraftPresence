import path from "node:path";
import { fileURLToPath } from "node:url";
import cookie from "@fastify/cookie";
import multipart from "@fastify/multipart";
import staticPlugin from "@fastify/static";
import websocket from "@fastify/websocket";
import Fastify from "fastify";
import { env } from "./config/env.js";
import { authPlugin } from "./plugins/auth.js";
import { errorHandlerPlugin } from "./plugins/errorHandler.js";
import { authRoutes } from "./auth/routes.js";
import { userRoutes } from "./users/routes.js";
import { deviceRoutes } from "./devices/routes.js";
import { imageAssetRoutes } from "./assets/routes.js";
import { backupRoutes } from "./backups/routes.js";
import { presenceRoutes } from "./presence/routes.js";
import { realtimeRoutes } from "./realtime/routes.js";

export async function buildApp() {
  const app = Fastify({ logger: env.NODE_ENV !== "test" });
  await app.register(cookie);
  await app.register(multipart, { limits: { fileSize: 5 * 1024 * 1024, files: 1 } });
  await app.register(websocket);
  await app.register(errorHandlerPlugin);
  await app.register(authPlugin);
  await app.register(authRoutes);
  await app.register(userRoutes);
  await app.register(deviceRoutes);
  await app.register(imageAssetRoutes);
  await app.register(backupRoutes);
  await app.register(presenceRoutes);
  await app.register(realtimeRoutes);

  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const clientDist = path.resolve(__dirname, "../../client/dist");
  await app.register(staticPlugin, { root: clientDist, prefix: "/" });
  app.setNotFoundHandler((request, reply) => {
    if (request.url.startsWith("/api/")) return reply.status(404).send({ message: "API route not found" });
    return reply.sendFile("index.html");
  });
  return app;
}

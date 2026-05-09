import type { FastifyInstance } from "fastify";
import { authenticateDeviceToken } from "../devices/deviceService.js";
import { getCurrentPresence } from "../presence/presenceService.js";
import { markDeviceOffline, markDeviceOnline, registerConnection, unregisterConnection } from "./deviceHub.js";

export async function realtimeRoutes(app: FastifyInstance) {
  app.get("/api/device/realtime", { websocket: true }, async (socket, request) => {
    const token = new URL(request.url, "http://localhost").searchParams.get("token") ?? undefined;
    const auth = await authenticateDeviceToken(token);
    if (!auth) {
      socket.close(1008, "Invalid device token");
      return;
    }
    registerConnection(auth.userId, auth.deviceId, socket);
    await markDeviceOnline(auth.deviceId);
    socket.send(JSON.stringify({ type: "connected", deviceId: auth.deviceId, serverTime: new Date().toISOString() }));
    socket.on("close", async () => {
      unregisterConnection(auth.userId, auth.deviceId, socket);
      await markDeviceOffline(auth.deviceId);
    });
  });

  app.get("/api/device/bootstrap", async (request) => {
    const token = extractBearer(request.headers.authorization);
    const auth = await authenticateDeviceToken(token);
    if (!auth) throw Object.assign(new Error("Invalid device token"), { statusCode: 401 });
    return {
      device: auth.device,
      currentPresence: await getCurrentPresence(auth.userId),
      serverTime: new Date().toISOString()
    };
  });
}

function extractBearer(value: string | undefined) {
  return value?.startsWith("Bearer ") ? value.slice("Bearer ".length) : undefined;
}

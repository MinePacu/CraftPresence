import type { WebSocket } from "@fastify/websocket";
import { eq } from "drizzle-orm";
import { db } from "../db/client.js";
import { devices } from "../db/schema.js";

type DeviceSocket = WebSocket;
const connections = new Map<string, Map<string, Set<DeviceSocket>>>();

export function registerConnection(userId: string, deviceId: string, socket: DeviceSocket) {
  let userConnections = connections.get(userId);
  if (!userConnections) {
    userConnections = new Map();
    connections.set(userId, userConnections);
  }
  let sockets = userConnections.get(deviceId);
  if (!sockets) {
    sockets = new Set();
    userConnections.set(deviceId, sockets);
  }
  sockets.add(socket);
}

export function unregisterConnection(userId: string, deviceId: string, socket: DeviceSocket) {
  const sockets = connections.get(userId)?.get(deviceId);
  sockets?.delete(socket);
  if (sockets?.size === 0) connections.get(userId)?.delete(deviceId);
}

export async function broadcastPresence(userId: string, originDeviceId: string, message: unknown) {
  const userConnections = connections.get(userId);
  if (!userConnections) return;
  const payload = JSON.stringify(message);
  for (const [deviceId, sockets] of userConnections.entries()) {
    if (deviceId === originDeviceId) continue;
    for (const socket of sockets) {
      if (socket.readyState === socket.OPEN) socket.send(payload);
    }
  }
}

export async function markDeviceOnline(deviceId: string) {
  await db.update(devices).set({ status: "online", lastSeenAt: new Date(), updatedAt: new Date() }).where(eq(devices.id, deviceId));
}

export async function markDeviceOffline(deviceId: string) {
  await db.update(devices).set({ status: "offline", updatedAt: new Date() }).where(eq(devices.id, deviceId));
}

import { createHash, randomBytes } from "node:crypto";
import { and, asc, eq, inArray, isNull } from "drizzle-orm";
import type { CreateDeviceInput, UpdateDeviceInput } from "@craftpresence/shared";
import { db } from "../db/client.js";
import { deviceTokens, devices } from "../db/schema.js";
import { env } from "../config/env.js";

export function hashDeviceToken(token: string) {
  return createHash("sha256").update(`${env.DEVICE_TOKEN_PEPPER}:${token}`).digest("hex");
}

export async function createDevice(userId: string, input: CreateDeviceInput) {
  const priority = input.priority ?? (await nextPriority(userId));
  const [device] = await db.insert(devices).values({ userId, name: input.name, platform: input.platform, priority }).returning();
  return device;
}

export async function listDevices(userId: string) {
  return db.select().from(devices).where(eq(devices.userId, userId)).orderBy(asc(devices.priority), asc(devices.createdAt));
}

export async function updateDevice(userId: string, deviceId: string, input: UpdateDeviceInput) {
  const [device] = await db
    .update(devices)
    .set({ ...input, updatedAt: new Date() })
    .where(and(eq(devices.userId, userId), eq(devices.id, deviceId)))
    .returning();
  return device;
}

export async function deleteDevice(userId: string, deviceId: string) {
  const [device] = await db.delete(devices).where(and(eq(devices.userId, userId), eq(devices.id, deviceId))).returning();
  return device;
}

export async function replaceDevicePriorities(userId: string, orderedDeviceIds: string[]) {
  const owned = await db.select({ id: devices.id }).from(devices).where(and(eq(devices.userId, userId), inArray(devices.id, orderedDeviceIds)));
  if (owned.length !== orderedDeviceIds.length) throw new Error("Priority list contains unknown devices");
  const updated = [];
  for (const [index, deviceId] of orderedDeviceIds.entries()) {
    const [device] = await db
      .update(devices)
      .set({ priority: index + 1, updatedAt: new Date() })
      .where(and(eq(devices.userId, userId), eq(devices.id, deviceId)))
      .returning();
    updated.push(device);
  }
  return updated;
}

export async function issueDeviceToken(userId: string, deviceId: string) {
  const [device] = await db.select().from(devices).where(and(eq(devices.userId, userId), eq(devices.id, deviceId))).limit(1);
  if (!device) throw new Error("Device not found");
  await db.update(deviceTokens).set({ revokedAt: new Date() }).where(and(eq(deviceTokens.userId, userId), eq(deviceTokens.deviceId, deviceId), isNull(deviceTokens.revokedAt)));
  const token = `cp_${randomBytes(32).toString("base64url")}`;
  await db.insert(deviceTokens).values({ userId, deviceId, tokenHash: hashDeviceToken(token) });
  return token;
}

export async function revokeDeviceToken(userId: string, deviceId: string) {
  await db.update(deviceTokens).set({ revokedAt: new Date() }).where(and(eq(deviceTokens.userId, userId), eq(deviceTokens.deviceId, deviceId), isNull(deviceTokens.revokedAt)));
}

export async function authenticateDeviceToken(token?: string) {
  if (!token) return undefined;
  const [row] = await db
    .select({ token: deviceTokens, device: devices })
    .from(deviceTokens)
    .innerJoin(devices, eq(deviceTokens.deviceId, devices.id))
    .where(and(eq(deviceTokens.tokenHash, hashDeviceToken(token)), isNull(deviceTokens.revokedAt)))
    .limit(1);
  if (!row) return undefined;
  await db.update(devices).set({ status: "online", lastSeenAt: new Date(), updatedAt: new Date() }).where(eq(devices.id, row.device.id));
  return { userId: row.token.userId, deviceId: row.token.deviceId, device: row.device };
}

async function nextPriority(userId: string) {
  const list = await listDevices(userId);
  return list.length + 1;
}

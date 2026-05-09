import { and, desc, eq, sql } from "drizzle-orm";
import { presenceEventInputSchema, type PresencePayload } from "@craftpresence/shared";
import { db } from "../db/client.js";
import { currentPresence, devices, presenceEvents } from "../db/schema.js";
import { resolvePresenceCandidate } from "./presenceResolver.js";
import { broadcastPresence } from "../realtime/deviceHub.js";
import { recordAuditEvent } from "../audit/auditService.js";

export async function recordPresenceEvent(userId: string, deviceId: string, input: unknown) {
  const parsed = presenceEventInputSchema.parse(input);
  const allDevices = await db.select().from(devices).where(eq(devices.userId, userId));
  const [current] = await db.select().from(currentPresence).where(eq(currentPresence.userId, userId)).limit(1);
  const resolution = resolvePresenceCandidate(allDevices, current ? { deviceId: current.deviceId, payload: current.payload as PresencePayload } : null, {
    deviceId,
    payload: parsed.payload
  });
  const [event] = await db
    .insert(presenceEvents)
    .values({
      userId,
      deviceId,
      payload: parsed.payload,
      status: resolution.applied ? "applied" : "ignored",
      reason: resolution.reason,
      occurredAt: parsed.occurredAt ? new Date(parsed.occurredAt) : new Date()
    })
    .returning();
  if (resolution.applied) {
    await db
      .insert(currentPresence)
      .values({ userId, deviceId, payload: parsed.payload })
      .onConflictDoUpdate({
        target: currentPresence.userId,
        set: { deviceId, payload: parsed.payload, updatedAt: new Date() }
      });
    await broadcastPresence(userId, deviceId, { type: "presence.updated", payload: parsed.payload, sourceDeviceId: deviceId });
    await recordAuditEvent({ actorDeviceId: deviceId, action: "presence.apply", entityType: "presenceEvent", entityId: event.id });
  }
  return event;
}

export async function getCurrentPresence(userId: string) {
  const [row] = await db.select().from(currentPresence).where(eq(currentPresence.userId, userId)).limit(1);
  return row ?? null;
}

export async function listPresenceEvents(userId: string, filters: { deviceId?: string; status?: "applied" | "ignored" } = {}) {
  const conditions = [eq(presenceEvents.userId, userId)];
  if (filters.deviceId) conditions.push(eq(presenceEvents.deviceId, filters.deviceId));
  if (filters.status) conditions.push(eq(presenceEvents.status, filters.status));
  return db.select().from(presenceEvents).where(and(...conditions)).orderBy(desc(presenceEvents.createdAt)).limit(200);
}

import { db } from "../db/client.js";
import { auditEvents } from "../db/schema.js";

export async function recordAuditEvent(input: {
  actorUserId?: string | null;
  actorDeviceId?: string | null;
  action: string;
  entityType: string;
  entityId?: string | null;
  metadata?: Record<string, unknown>;
}) {
  await db.insert(auditEvents).values({
    actorUserId: input.actorUserId ?? null,
    actorDeviceId: input.actorDeviceId ?? null,
    action: input.action,
    entityType: input.entityType,
    entityId: input.entityId ?? null,
    metadata: input.metadata ?? {}
  });
}

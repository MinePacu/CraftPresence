import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { requireCurrentUser } from "../plugins/auth.js";
import { createBackup, deleteBackup, getBackup, listBackups, updateBackup } from "./backupService.js";
import { recordAuditEvent } from "../audit/auditService.js";

export async function backupRoutes(app: FastifyInstance) {
  app.get("/api/backups", async (request) => {
    const user = requireCurrentUser(request);
    return { backups: await listBackups(user.id) };
  });

  app.post("/api/backups/upload", async (request) => {
    const user = requireCurrentUser(request);
    const input = z.object({ rawJson: z.unknown(), deviceId: z.string().uuid().nullable().optional() }).parse(request.body);
    const backup = await createBackup(user.id, input.rawJson, input.deviceId);
    await recordAuditEvent({ actorUserId: user.id, action: "backup.create", entityType: "settingsBackup", entityId: backup.id });
    return { backup };
  });

  app.get("/api/backups/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const backup = await getBackup(user.id, id);
    if (!backup) throw Object.assign(new Error("Backup not found"), { statusCode: 404 });
    return { backup };
  });

  app.patch("/api/backups/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const input = z.object({ rawJson: z.unknown() }).parse(request.body);
    const backup = await updateBackup(user.id, id, input.rawJson);
    if (!backup) throw Object.assign(new Error("Backup not found"), { statusCode: 404 });
    await recordAuditEvent({ actorUserId: user.id, action: "backup.update", entityType: "settingsBackup", entityId: id });
    return { backup };
  });

  app.delete("/api/backups/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const backup = await deleteBackup(user.id, id);
    if (!backup) throw Object.assign(new Error("Backup not found"), { statusCode: 404 });
    await recordAuditEvent({ actorUserId: user.id, action: "backup.delete", entityType: "settingsBackup", entityId: id });
    return { ok: true };
  });
}

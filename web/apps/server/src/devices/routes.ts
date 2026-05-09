import type { FastifyInstance } from "fastify";
import { createDeviceInputSchema, updateDeviceInputSchema } from "@craftpresence/shared";
import { z } from "zod";
import { requireCurrentUser } from "../plugins/auth.js";
import { createDevice, deleteDevice, issueDeviceToken, listDevices, replaceDevicePriorities, revokeDeviceToken, updateDevice } from "./deviceService.js";
import { recordAuditEvent } from "../audit/auditService.js";

export async function deviceRoutes(app: FastifyInstance) {
  app.get("/api/devices", async (request) => listDevices(requireCurrentUser(request).id));

  app.post("/api/devices", async (request) => {
    const user = requireCurrentUser(request);
    const device = await createDevice(user.id, createDeviceInputSchema.parse(request.body));
    await recordAuditEvent({ actorUserId: user.id, action: "device.create", entityType: "device", entityId: device.id });
    return { device };
  });

  app.patch("/api/devices/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const device = await updateDevice(user.id, id, updateDeviceInputSchema.parse(request.body));
    if (!device) throw Object.assign(new Error("Device not found"), { statusCode: 404 });
    return { device };
  });

  app.delete("/api/devices/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const device = await deleteDevice(user.id, id);
    if (!device) throw Object.assign(new Error("Device not found"), { statusCode: 404 });
    await recordAuditEvent({ actorUserId: user.id, action: "device.delete", entityType: "device", entityId: id });
    return { ok: true };
  });

  app.put("/api/devices/priorities", async (request) => {
    const user = requireCurrentUser(request);
    const input = z.object({ orderedDeviceIds: z.array(z.string().uuid()) }).parse(request.body);
    const devices = await replaceDevicePriorities(user.id, input.orderedDeviceIds);
    await recordAuditEvent({ actorUserId: user.id, action: "device.priorities", entityType: "device", metadata: { orderedDeviceIds: input.orderedDeviceIds } });
    return { devices };
  });

  app.post("/api/devices/:id/token", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const token = await issueDeviceToken(user.id, id);
    await recordAuditEvent({ actorUserId: user.id, action: "device.token.issue", entityType: "device", entityId: id });
    return { token };
  });

  app.delete("/api/devices/:id/token", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    await revokeDeviceToken(user.id, id);
    await recordAuditEvent({ actorUserId: user.id, action: "device.token.revoke", entityType: "device", entityId: id });
    return { ok: true };
  });
}

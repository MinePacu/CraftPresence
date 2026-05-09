import { z } from "zod";
import { platformSchema } from "./platform.js";

export const deviceStatusSchema = z.enum(["online", "offline", "disabled"]);
export type DeviceStatus = z.infer<typeof deviceStatusSchema>;

export const deviceSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
  name: z.string(),
  platform: platformSchema,
  priority: z.number().int().positive(),
  status: deviceStatusSchema,
  lastSeenAt: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string()
});
export type Device = z.infer<typeof deviceSchema>;

export const createDeviceInputSchema = z.object({
  name: z.string().trim().min(1).max(80),
  platform: platformSchema,
  priority: z.number().int().positive().optional()
});
export type CreateDeviceInput = z.infer<typeof createDeviceInputSchema>;

export const updateDeviceInputSchema = z.object({
  name: z.string().trim().min(1).max(80).optional(),
  platform: platformSchema.optional(),
  priority: z.number().int().positive().optional(),
  status: deviceStatusSchema.optional()
});
export type UpdateDeviceInput = z.infer<typeof updateDeviceInputSchema>;

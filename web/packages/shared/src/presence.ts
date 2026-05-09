import { z } from "zod";

export const activityTypeSchema = z.enum([
  "playing",
  "streaming",
  "listening",
  "watching",
  "customStatus",
  "competing",
  "hangStatus"
]);
export type ActivityType = z.infer<typeof activityTypeSchema>;

export const presencePayloadSchema = z.object({
  name: z.string().max(128).nullable().optional(),
  state: z.string().max(128).nullable().optional(),
  details: z.string().max(128).nullable().optional(),
  activityType: activityTypeSchema.default("playing"),
  largeImageKey: z.string().max(64).nullable().optional(),
  largeImageText: z.string().max(128).nullable().optional(),
  smallImageKey: z.string().max(64).nullable().optional(),
  smallImageText: z.string().max(128).nullable().optional(),
  partyId: z.string().max(128).nullable().optional(),
  partyCurrent: z.number().int().positive().nullable().optional(),
  partyMax: z.number().int().positive().nullable().optional(),
  startEpochSeconds: z.number().int().positive().nullable().optional(),
  endEpochSeconds: z.number().int().positive().nullable().optional()
});
export type PresencePayload = z.infer<typeof presencePayloadSchema>;

export const presenceEventInputSchema = z.object({
  payload: presencePayloadSchema,
  occurredAt: z.string().datetime().optional()
});
export type PresenceEventInput = z.infer<typeof presenceEventInputSchema>;

export const presenceEventStatusSchema = z.enum(["applied", "ignored"]);
export type PresenceEventStatus = z.infer<typeof presenceEventStatusSchema>;

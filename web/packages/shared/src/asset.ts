import { z } from "zod";

export const discordImageRoleSchema = z.enum(["large", "small", "both"]);
export type DiscordImageRole = z.infer<typeof discordImageRoleSchema>;

export const imageAssetSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
  title: z.string().min(1),
  key: z.string().regex(/^[a-z0-9_-]{2,64}$/),
  imageText: z.string().max(128).default(""),
  role: discordImageRoleSchema.default("both"),
  originalFilename: z.string(),
  mimeType: z.enum(["image/png", "image/jpeg", "image/webp"]),
  byteSize: z.number().int().positive(),
  width: z.number().int().positive().nullable(),
  height: z.number().int().positive().nullable(),
  createdAt: z.string(),
  updatedAt: z.string()
});
export type ImageAsset = z.infer<typeof imageAssetSchema>;

export const createImageAssetInputSchema = z.object({
  title: z.string().trim().min(1).max(80),
  key: z.string().regex(/^[a-z0-9_-]{2,64}$/).optional(),
  imageText: z.string().max(128).optional(),
  role: discordImageRoleSchema.optional()
});
export type CreateImageAssetInput = z.infer<typeof createImageAssetInputSchema>;

export const updateImageAssetInputSchema = createImageAssetInputSchema.partial();
export type UpdateImageAssetInput = z.infer<typeof updateImageAssetInputSchema>;

export function generateDiscordAssetKey(titleOrFilename: string): string {
  const normalized = titleOrFilename
    .toLowerCase()
    .replace(/\.[a-z0-9]+$/i, "")
    .trim()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 64);

  if (normalized.length >= 2) return normalized;
  return `asset_${normalized || "image"}`.slice(0, 64);
}

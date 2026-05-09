import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { fileTypeFromBuffer } from "file-type";
import { imageSize } from "image-size";
import { createImageAssetInputSchema, generateDiscordAssetKey, type UpdateImageAssetInput } from "@craftpresence/shared";
import { db } from "../db/client.js";
import { imageAssets } from "../db/schema.js";
import { deleteImageFile, resolveImagePath, saveImageFile } from "../storage/localFileStore.js";

export async function createImageAsset(
  userId: string,
  metadata: unknown,
  uploadedFile: { filename: string; bytes: Buffer; mimetype?: string }
) {
  const input = createImageAssetInputSchema.parse(metadata);
  const detected = await fileTypeFromBuffer(uploadedFile.bytes);
  const mimeType = detected?.mime ?? uploadedFile.mimetype ?? "";
  if (!["image/png", "image/jpeg", "image/webp"].includes(mimeType)) throw new Error("Unsupported image type");
  const key = input.key ?? generateDiscordAssetKey(input.title || uploadedFile.filename);
  await assertKeyAvailable(userId, key);
  const assetId = randomUUID();
  const dimensions = imageSize(uploadedFile.bytes);
  const saved = await saveImageFile(userId, assetId, mimeType, uploadedFile.bytes);
  const [asset] = await db
    .insert(imageAssets)
    .values({
      id: assetId,
      userId,
      title: input.title,
      key,
      imageText: input.imageText ?? input.title,
      role: input.role ?? "both",
      originalFilename: uploadedFile.filename,
      mimeType,
      byteSize: uploadedFile.bytes.length,
      width: dimensions.width ?? null,
      height: dimensions.height ?? null,
      storagePath: saved.storagePath,
      sha256: saved.sha256
    })
    .returning();
  return asset;
}

export async function listImageAssets(userId: string) {
  return db.select().from(imageAssets).where(eq(imageAssets.userId, userId)).orderBy(asc(imageAssets.title));
}

export async function getImageAsset(userId: string, assetId: string) {
  const [asset] = await db.select().from(imageAssets).where(and(eq(imageAssets.userId, userId), eq(imageAssets.id, assetId))).limit(1);
  return asset;
}

export async function updateImageAsset(userId: string, assetId: string, input: UpdateImageAssetInput) {
  if (input.key) await assertKeyAvailable(userId, input.key, assetId);
  const [asset] = await db
    .update(imageAssets)
    .set({ ...input, updatedAt: new Date() })
    .where(and(eq(imageAssets.userId, userId), eq(imageAssets.id, assetId)))
    .returning();
  return asset;
}

export async function deleteImageAsset(userId: string, assetId: string) {
  const asset = await getImageAsset(userId, assetId);
  if (!asset) return undefined;
  await db.delete(imageAssets).where(and(eq(imageAssets.userId, userId), eq(imageAssets.id, assetId)));
  await deleteImageFile(asset.storagePath);
  return asset;
}

export async function readImageAssetFile(userId: string, assetId: string) {
  const asset = await getImageAsset(userId, assetId);
  if (!asset) return undefined;
  return { asset, bytes: await resolveImagePath(asset.storagePath) };
}

export function buildDiscordFieldSnippet(asset: { key: string; imageText: string }, role: "large" | "small") {
  if (role === "large") return { largeImageKey: asset.key, largeImageText: asset.imageText };
  return { smallImageKey: asset.key, smallImageText: asset.imageText };
}

async function assertKeyAvailable(userId: string, key: string, ignoreAssetId?: string) {
  const [existing] = await db.select().from(imageAssets).where(and(eq(imageAssets.userId, userId), eq(imageAssets.key, key))).limit(1);
  if (existing && existing.id !== ignoreAssetId) throw Object.assign(new Error("Image asset key already exists"), { statusCode: 409 });
}

import { createHash } from "node:crypto";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { env } from "../config/env.js";

const extensionByMime: Record<string, string> = {
  "image/png": ".png",
  "image/jpeg": ".jpg",
  "image/webp": ".webp"
};

export async function saveImageFile(userId: string, assetId: string, mimeType: string, bytes: Buffer) {
  const extension = extensionByMime[mimeType];
  if (!extension) throw new Error("Unsupported image MIME type.");
  const directory = path.join(env.IMAGE_STORAGE_PATH, userId);
  await mkdir(directory, { recursive: true });
  const storagePath = path.join(directory, `${assetId}${extension}`);
  await writeFile(storagePath, bytes);
  return {
    storagePath,
    sha256: createHash("sha256").update(bytes).digest("hex")
  };
}

export async function deleteImageFile(storagePath: string) {
  await rm(storagePath, { force: true });
}

export async function resolveImagePath(storagePath: string) {
  return readFile(storagePath);
}

import type { FastifyInstance } from "fastify";
import { updateImageAssetInputSchema } from "@craftpresence/shared";
import { z } from "zod";
import { requireCurrentUser } from "../plugins/auth.js";
import { authenticateDeviceToken } from "../devices/deviceService.js";
import { buildDiscordFieldSnippet, createImageAsset, deleteImageAsset, getImageAsset, listImageAssets, readImageAssetFile, updateImageAsset } from "./imageAssetService.js";
import { recordAuditEvent } from "../audit/auditService.js";

export async function imageAssetRoutes(app: FastifyInstance) {
  app.get("/api/assets", async (request) => {
    const user = requireCurrentUser(request);
    const assets = await listImageAssets(user.id);
    return { assets: assets.map(toResponse) };
  });

  app.post("/api/assets", async (request) => {
    const user = requireCurrentUser(request);
    const parts = request.parts();
    const fields: Record<string, string> = {};
    let file: { filename: string; bytes: Buffer; mimetype?: string } | undefined;
    for await (const part of parts) {
      if (part.type === "file") {
        file = { filename: part.filename, bytes: await part.toBuffer(), mimetype: part.mimetype };
      } else {
        fields[part.fieldname] = String(part.value ?? "");
      }
    }
    if (!file) throw Object.assign(new Error("Image file is required"), { statusCode: 400 });
    const asset = await createImageAsset(user.id, fields, file);
    await recordAuditEvent({ actorUserId: user.id, action: "asset.create", entityType: "imageAsset", entityId: asset.id });
    return { asset: toResponse(asset) };
  });

  app.get("/api/assets/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const asset = await getImageAsset(user.id, id);
    if (!asset) throw Object.assign(new Error("Asset not found"), { statusCode: 404 });
    return { asset: toResponse(asset) };
  });

  app.patch("/api/assets/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const asset = await updateImageAsset(user.id, id, updateImageAssetInputSchema.parse(request.body));
    if (!asset) throw Object.assign(new Error("Asset not found"), { statusCode: 404 });
    await recordAuditEvent({ actorUserId: user.id, action: "asset.update", entityType: "imageAsset", entityId: id });
    return { asset: toResponse(asset) };
  });

  app.delete("/api/assets/:id", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const asset = await deleteImageAsset(user.id, id);
    if (!asset) throw Object.assign(new Error("Asset not found"), { statusCode: 404 });
    await recordAuditEvent({ actorUserId: user.id, action: "asset.delete", entityType: "imageAsset", entityId: id });
    return { ok: true };
  });

  app.get("/api/assets/:id/image", async (request, reply) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const result = await readImageAssetFile(user.id, id);
    if (!result) throw Object.assign(new Error("Asset not found"), { statusCode: 404 });
    return reply.type(result.asset.mimeType).send(result.bytes);
  });

  app.post("/api/assets/:id/snippet", async (request) => {
    const user = requireCurrentUser(request);
    const { id } = z.object({ id: z.string().uuid() }).parse(request.params);
    const { role } = z.object({ role: z.enum(["large", "small"]) }).parse(request.body);
    const asset = await getImageAsset(user.id, id);
    if (!asset) throw Object.assign(new Error("Asset not found"), { statusCode: 404 });
    return buildDiscordFieldSnippet(asset, role);
  });

  app.get("/api/device/assets", async (request) => {
    const auth = await authenticateDeviceToken(extractBearer(request.headers.authorization));
    if (!auth) throw Object.assign(new Error("Invalid device token"), { statusCode: 401 });
    const assets = await listImageAssets(auth.userId);
    return {
      assets: assets.map((asset) => ({
        ...toResponse(asset),
        largeSnippet: buildDiscordFieldSnippet(asset, "large"),
        smallSnippet: buildDiscordFieldSnippet(asset, "small")
      }))
    };
  });
}

function toResponse(asset: Awaited<ReturnType<typeof listImageAssets>>[number]) {
  return {
    id: asset.id,
    userId: asset.userId,
    title: asset.title,
    key: asset.key,
    imageText: asset.imageText,
    role: asset.role,
    originalFilename: asset.originalFilename,
    mimeType: asset.mimeType,
    byteSize: asset.byteSize,
    width: asset.width,
    height: asset.height,
    imageUrl: `/api/assets/${asset.id}/image`,
    createdAt: asset.createdAt.toISOString(),
    updatedAt: asset.updatedAt.toISOString()
  };
}

function extractBearer(value: string | undefined) {
  return value?.startsWith("Bearer ") ? value.slice("Bearer ".length) : undefined;
}

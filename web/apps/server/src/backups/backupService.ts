import { and, desc, eq } from "drizzle-orm";
import { decodeSettingsBackup, summarizeSettingsBackup } from "@craftpresence/shared";
import { db } from "../db/client.js";
import { settingsBackups } from "../db/schema.js";

export async function createBackup(userId: string, raw: unknown, deviceId?: string | null) {
  const backup = decodeSettingsBackup(typeof raw === "string" ? raw : JSON.stringify(raw));
  const summary = summarizeSettingsBackup(backup);
  const [row] = await db
    .insert(settingsBackups)
    .values({ userId, deviceId: deviceId ?? null, platform: backup.platform, schemaVersion: backup.schemaVersion, rawJson: backup, summary })
    .returning();
  return row;
}

export async function listBackups(userId: string) {
  return db.select().from(settingsBackups).where(eq(settingsBackups.userId, userId)).orderBy(desc(settingsBackups.updatedAt));
}

export async function getBackup(userId: string, backupId: string) {
  const [row] = await db.select().from(settingsBackups).where(and(eq(settingsBackups.userId, userId), eq(settingsBackups.id, backupId))).limit(1);
  return row;
}

export async function updateBackup(userId: string, backupId: string, raw: unknown) {
  const backup = decodeSettingsBackup(typeof raw === "string" ? raw : JSON.stringify(raw));
  const [row] = await db
    .update(settingsBackups)
    .set({ platform: backup.platform, schemaVersion: backup.schemaVersion, rawJson: backup, summary: summarizeSettingsBackup(backup), updatedAt: new Date() })
    .where(and(eq(settingsBackups.userId, userId), eq(settingsBackups.id, backupId)))
    .returning();
  return row;
}

export async function deleteBackup(userId: string, backupId: string) {
  const [row] = await db.delete(settingsBackups).where(and(eq(settingsBackups.userId, userId), eq(settingsBackups.id, backupId))).returning();
  return row;
}

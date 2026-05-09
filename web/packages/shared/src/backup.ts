import { z } from "zod";
import { activityTypeSchema, presencePayloadSchema } from "./presence.js";
import { platformSchema } from "./platform.js";

export const programPresenceSettingsSchema = z.object({
  activityType: activityTypeSchema.default("playing"),
  presetID: z.string().nullable().optional(),
  detailText: z.string().default(""),
  stateText: z.string().default(""),
  useAppIconForLargeImage: z.boolean().default(true),
  largeImageKey: z.string().default(""),
  largeImageText: z.string().default(""),
  smallImageKey: z.string().default(""),
  smallImageText: z.string().default(""),
  resetElapsedTimeOnPresenceChange: z.boolean().default(true),
  partyCurrent: z.number().int().positive().default(1),
  partyMax: z.number().int().positive().default(1)
});

export const presencePresetSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  activityType: activityTypeSchema.default("playing"),
  details: z.string().default(""),
  state: z.string().default(""),
  largeImageKey: z.string().default(""),
  largeImageText: z.string().default(""),
  smallImageKey: z.string().default(""),
  smallImageText: z.string().default(""),
  usesElapsedTime: z.boolean().default(true),
  resetsElapsedTimeOnPublish: z.boolean().default(true),
  usesParty: z.boolean().default(false),
  partyCurrent: z.number().int().positive().default(1),
  partyMax: z.number().int().positive().default(1),
  isDefault: z.boolean().default(false),
  updatedAt: z.string().default("1970-01-01T00:00:00.000Z")
});

export const appSettingsSchema = z.object({
  packageNames: z.array(z.string()).default([]),
  appDisplayNames: z.record(z.string()).default({}),
  programSettings: z.record(programPresenceSettingsSchema).default({}),
  presencePresets: z.array(presencePresetSchema).default([]),
  activePresencePresetID: z.string().nullable().optional(),
  appliedPresence: presencePayloadSchema.nullable().optional(),
  preferredLanguage: z.enum(["system", "ko", "en", "ja"]).default("system"),
  programPresenceEnabled: z.boolean().default(true),
  showForegroundAppIndicator: z.boolean().default(true),
  showForegroundAppNotification: z.boolean().default(false),
  hasCompletedDiscordOnboarding: z.boolean().default(false),
  resetElapsedTimeOnScheduledPresetRestore: z.boolean().default(false)
});
export type AppSettings = z.infer<typeof appSettingsSchema>;

export const settingsBackupFileSchema = z.object({
  schemaVersion: z.number().int().min(1),
  appName: z.string().default("CraftPresence"),
  appVersion: z.string().nullable().optional(),
  buildNumber: z.string().nullable().optional(),
  exportedAt: z.string(),
  platform: z.union([platformSchema, z.literal("legacy")]),
  settings: appSettingsSchema,
  platformExtensions: z.record(z.unknown()).default({})
});
export type SettingsBackupFile = z.infer<typeof settingsBackupFileSchema>;

export function decodeSettingsBackup(raw: unknown): SettingsBackupFile {
  const root = typeof raw === "string" ? JSON.parse(raw) : raw;
  const value = root as Record<string, unknown>;
  const candidate =
    value && typeof value === "object" && "schemaVersion" in value && "settings" in value
      ? value
      : {
          schemaVersion: 1,
          appName: "CraftPresence",
          appVersion: null,
          buildNumber: null,
          exportedAt: "1970-01-01T00:00:00.000Z",
          platform: "legacy",
          settings: value,
          platformExtensions: {}
        };
  const parsed = settingsBackupFileSchema.parse(candidate);
  validateSettingsBackup(parsed);
  return parsed;
}

export function validateSettingsBackup(backup: SettingsBackupFile): void {
  if (backup.schemaVersion !== 1) {
    throw new Error(`Unsupported settings backup schema version: ${backup.schemaVersion}.`);
  }
  const packages = backup.settings.packageNames.map((name) => name.trim()).filter(Boolean);
  const duplicatePackage = findDuplicate(packages);
  if (duplicatePackage) throw new Error(`Settings backup contains a duplicate package: ${duplicatePackage}.`);

  const presetIds = backup.settings.presencePresets.map((preset) => preset.id.trim()).filter(Boolean);
  const duplicatePreset = findDuplicate(presetIds);
  if (duplicatePreset) throw new Error(`Settings backup contains a duplicate Presence preset: ${duplicatePreset}.`);

  if (backup.settings.activePresencePresetID && !presetIds.includes(backup.settings.activePresencePresetID)) {
    throw new Error(`Settings backup references a missing active Presence preset: ${backup.settings.activePresencePresetID}.`);
  }
}

export function summarizeSettingsBackup(backup: SettingsBackupFile) {
  return {
    schemaVersion: backup.schemaVersion,
    platform: backup.platform,
    exportedAt: backup.exportedAt,
    presetCount: backup.settings.presencePresets.length,
    trackedProgramCount: backup.settings.packageNames.length,
    language: backup.settings.preferredLanguage
  };
}

function findDuplicate(values: string[]): string | undefined {
  const seen = new Set<string>();
  for (const value of values) {
    if (seen.has(value)) return value;
    seen.add(value);
  }
  return undefined;
}

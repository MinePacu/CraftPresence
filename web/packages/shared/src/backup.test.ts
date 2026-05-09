import { describe, expect, it } from "vitest";
import { decodeSettingsBackup, summarizeSettingsBackup } from "./backup.js";

describe("settings backup schema", () => {
  it("accepts the current CraftPresence backup envelope", () => {
    const backup = decodeSettingsBackup({
      schemaVersion: 1,
      appName: "CraftPresence",
      appVersion: null,
      buildNumber: null,
      exportedAt: "2026-05-10T00:00:00.000Z",
      platform: "macOS",
      settings: {
        packageNames: ["com.apple.dt.Xcode"],
        presencePresets: [{ id: "coding", title: "Coding" }],
        preferredLanguage: "ko"
      },
      platformExtensions: {}
    });

    expect(summarizeSettingsBackup(backup)).toMatchObject({
      platform: "macOS",
      presetCount: 1,
      trackedProgramCount: 1,
      language: "ko"
    });
  });

  it("rejects a missing active preset reference", () => {
    expect(() =>
      decodeSettingsBackup({
        schemaVersion: 1,
        appName: "CraftPresence",
        exportedAt: "2026-05-10T00:00:00.000Z",
        platform: "Android",
        settings: {
          activePresencePresetID: "missing",
          presencePresets: [{ id: "existing", title: "Existing" }]
        },
        platformExtensions: {}
      })
    ).toThrow(/missing active Presence preset/);
  });
});

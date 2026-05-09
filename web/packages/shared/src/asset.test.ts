import { describe, expect, it } from "vitest";
import { generateDiscordAssetKey } from "./asset.js";

describe("generateDiscordAssetKey", () => {
  it("normalizes filenames into Discord-compatible asset keys", () => {
    expect(generateDiscordAssetKey("Apple Music Icon.png")).toBe("apple_music_icon");
  });

  it("returns a fallback key when the input has no usable characters", () => {
    expect(generateDiscordAssetKey("!!!")).toBe("asset_image");
  });
});

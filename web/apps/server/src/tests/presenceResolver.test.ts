import { describe, expect, it } from "vitest";
import { resolvePresenceCandidate } from "../presence/presenceResolver.js";

const devices = [
  { id: "high", priority: 1, status: "online" as const },
  { id: "low", priority: 2, status: "online" as const }
];

describe("resolvePresenceCandidate", () => {
  it("blocks lower-priority devices while a higher-priority device is online", () => {
    const result = resolvePresenceCandidate(devices, { deviceId: "high", payload: { activityType: "playing", name: "High" } }, {
      deviceId: "low",
      payload: { activityType: "playing", name: "Low" }
    });

    expect(result).toEqual({ applied: false, reason: "higher_priority_device_online" });
  });

  it("allows the same device to replace its current Presence", () => {
    const result = resolvePresenceCandidate(devices, { deviceId: "low", payload: { activityType: "playing", name: "Old" } }, {
      deviceId: "low",
      payload: { activityType: "playing", name: "New" }
    });

    expect(result).toEqual({ applied: true, reason: "same_device_latest_event" });
  });
});

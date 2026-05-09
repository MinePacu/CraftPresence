import type { PresencePayload } from "@craftpresence/shared";

export type ResolverDevice = {
  id: string;
  priority: number;
  status: "online" | "offline" | "disabled";
};

export type CurrentPresenceState = {
  deviceId: string | null;
  payload: PresencePayload;
} | null;

export function resolvePresenceCandidate(
  devices: ResolverDevice[],
  currentPresence: CurrentPresenceState,
  incomingEvent: { deviceId: string; payload: PresencePayload }
) {
  const incomingDevice = devices.find((device) => device.id === incomingEvent.deviceId);
  if (!incomingDevice) return { applied: false, reason: "unknown_device" };
  if (incomingDevice.status === "disabled") return { applied: false, reason: "disabled_device" };
  if (!currentPresence) return { applied: true, reason: "no_current_presence" };
  if (currentPresence.deviceId === incomingEvent.deviceId) return { applied: true, reason: "same_device_latest_event" };

  const blockingDevice = devices
    .filter((device) => device.status === "online" && device.priority < incomingDevice.priority)
    .sort((a, b) => a.priority - b.priority)[0];
  if (blockingDevice) return { applied: false, reason: "higher_priority_device_online" };
  return { applied: true, reason: "highest_available_priority" };
}

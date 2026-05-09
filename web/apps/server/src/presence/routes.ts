import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { requireCurrentUser } from "../plugins/auth.js";
import { authenticateDeviceToken } from "../devices/deviceService.js";
import { getCurrentPresence, listPresenceEvents, recordPresenceEvent } from "./presenceService.js";

export async function presenceRoutes(app: FastifyInstance) {
  app.get("/api/presence/current", async (request) => {
    const user = requireCurrentUser(request);
    return { currentPresence: await getCurrentPresence(user.id) };
  });

  app.get("/api/presence/events", async (request) => {
    const user = requireCurrentUser(request);
    const query = z.object({ deviceId: z.string().uuid().optional(), status: z.enum(["applied", "ignored"]).optional() }).parse(request.query);
    return { events: await listPresenceEvents(user.id, query) };
  });

  app.post("/api/device/presence-events", async (request) => {
    const auth = await authenticateDeviceToken(extractBearer(request.headers.authorization));
    if (!auth) throw Object.assign(new Error("Invalid device token"), { statusCode: 401 });
    const event = await recordPresenceEvent(auth.userId, auth.deviceId, request.body);
    return { event };
  });
}

function extractBearer(value: string | undefined) {
  return value?.startsWith("Bearer ") ? value.slice("Bearer ".length) : undefined;
}

import type { FastifyInstance } from "fastify";
import { ZodError } from "zod";

export async function errorHandlerPlugin(app: FastifyInstance) {
  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({ error: "ValidationError", message: error.issues[0]?.message ?? "Invalid input" });
    }
    const typedError = error as Error & { statusCode?: number };
    const statusCode = Number(typedError.statusCode ?? 500);
    return reply.status(statusCode).send({
      error: statusCode >= 500 ? "InternalServerError" : "RequestError",
      message: statusCode >= 500 ? "Unexpected server error" : typedError.message
    });
  });
}

import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  HOST: z.string().default("0.0.0.0"),
  PORT: z.coerce.number().int().positive().default(8080),
  DATABASE_URL: z.string().min(1),
  SESSION_SECRET: z.string().min(32),
  DEVICE_TOKEN_PEPPER: z.string().min(32),
  COOKIE_SECURE: z.coerce.boolean().default(false),
  IMAGE_STORAGE_PATH: z.string().min(1).default("/app/data/images")
});

export const env = envSchema.parse({
  NODE_ENV: process.env.NODE_ENV ?? "development",
  HOST: process.env.HOST ?? "0.0.0.0",
  PORT: process.env.PORT ?? "8080",
  DATABASE_URL: process.env.DATABASE_URL ?? "postgres://craftpresence:craftpresence@localhost:5432/craftpresence",
  SESSION_SECRET: process.env.SESSION_SECRET ?? "development-session-secret-change-before-production",
  DEVICE_TOKEN_PEPPER: process.env.DEVICE_TOKEN_PEPPER ?? "development-device-token-pepper-change-prod",
  COOKIE_SECURE: process.env.COOKIE_SECURE ?? "false",
  IMAGE_STORAGE_PATH: process.env.IMAGE_STORAGE_PATH ?? "/app/data/images"
});

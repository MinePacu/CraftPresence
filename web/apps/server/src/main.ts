import { buildApp } from "./app.js";
import { env } from "./config/env.js";
import { runMigrations } from "./db/migrate.js";

await runMigrations();
const app = await buildApp();
await app.listen({ host: env.HOST, port: env.PORT });

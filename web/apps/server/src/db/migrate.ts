import { migrate } from "drizzle-orm/node-postgres/migrator";
import { db, pool } from "./client.js";

export async function runMigrations() {
  await migrate(db, { migrationsFolder: "apps/server/drizzle" });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  await runMigrations();
  await pool.end();
}

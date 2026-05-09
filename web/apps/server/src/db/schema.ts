import { relations, sql } from "drizzle-orm";
import { boolean, index, integer, jsonb, pgEnum, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";

export const roleEnum = pgEnum("user_role", ["admin", "user"]);
export const platformEnum = pgEnum("platform", ["macOS", "iOS", "Android", "Windows", "Linux"]);
export const deviceStatusEnum = pgEnum("device_status", ["online", "offline", "disabled"]);
export const imageRoleEnum = pgEnum("image_role", ["large", "small", "both"]);
export const eventStatusEnum = pgEnum("presence_event_status", ["applied", "ignored"]);

const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull()
};

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  displayName: text("display_name").notNull(),
  passwordHash: text("password_hash").notNull(),
  role: roleEnum("role").default("admin").notNull(),
  ...timestamps
});

export const sessions = pgTable(
  "sessions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }).notNull(),
    tokenHash: text("token_hash").notNull().unique(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull()
  },
  (table) => ({ userIdx: index("sessions_user_id_idx").on(table.userId) })
);

export const devices = pgTable(
  "devices",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }).notNull(),
    name: text("name").notNull(),
    platform: platformEnum("platform").notNull(),
    priority: integer("priority").notNull(),
    status: deviceStatusEnum("status").default("offline").notNull(),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
    ...timestamps
  },
  (table) => ({
    userIdx: index("devices_user_id_idx").on(table.userId),
    userPriorityIdx: index("devices_user_priority_idx").on(table.userId, table.priority)
  })
);

export const deviceTokens = pgTable(
  "device_tokens",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }).notNull(),
    deviceId: uuid("device_id").references(() => devices.id, { onDelete: "cascade" }).notNull(),
    tokenHash: text("token_hash").notNull().unique(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    revokedAt: timestamp("revoked_at", { withTimezone: true })
  },
  (table) => ({
    userIdx: index("device_tokens_user_id_idx").on(table.userId),
    deviceIdx: index("device_tokens_device_id_idx").on(table.deviceId)
  })
);

export const imageAssets = pgTable(
  "image_assets",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }).notNull(),
    title: text("title").notNull(),
    key: text("key").notNull(),
    imageText: text("image_text").default("").notNull(),
    role: imageRoleEnum("role").default("both").notNull(),
    originalFilename: text("original_filename").notNull(),
    mimeType: text("mime_type").notNull(),
    byteSize: integer("byte_size").notNull(),
    width: integer("width"),
    height: integer("height"),
    storagePath: text("storage_path").notNull(),
    sha256: text("sha256").notNull(),
    ...timestamps
  },
  (table) => ({
    userIdx: index("image_assets_user_id_idx").on(table.userId),
    keyIdx: index("image_assets_key_idx").on(table.key),
    userKeyUnique: uniqueIndex("image_assets_user_key_unique").on(table.userId, table.key)
  })
);

export const settingsBackups = pgTable(
  "settings_backups",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }).notNull(),
    deviceId: uuid("device_id").references(() => devices.id, { onDelete: "set null" }),
    platform: text("platform").notNull(),
    schemaVersion: integer("schema_version").notNull(),
    rawJson: jsonb("raw_json").notNull(),
    summary: jsonb("summary").notNull(),
    ...timestamps
  },
  (table) => ({
    userIdx: index("settings_backups_user_id_idx").on(table.userId),
    deviceIdx: index("settings_backups_device_id_idx").on(table.deviceId)
  })
);

export const currentPresence = pgTable(
  "current_presence",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }).notNull().unique(),
    deviceId: uuid("device_id").references(() => devices.id, { onDelete: "set null" }),
    payload: jsonb("payload").notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull()
  },
  (table) => ({ userIdx: index("current_presence_user_id_idx").on(table.userId) })
);

export const presenceEvents = pgTable(
  "presence_events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }).notNull(),
    deviceId: uuid("device_id").references(() => devices.id, { onDelete: "set null" }),
    payload: jsonb("payload").notNull(),
    status: eventStatusEnum("status").notNull(),
    reason: text("reason"),
    occurredAt: timestamp("occurred_at", { withTimezone: true }).default(sql`now()`).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull()
  },
  (table) => ({
    userIdx: index("presence_events_user_id_idx").on(table.userId),
    deviceIdx: index("presence_events_device_id_idx").on(table.deviceId)
  })
);

export const auditEvents = pgTable(
  "audit_events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    actorUserId: uuid("actor_user_id").references(() => users.id, { onDelete: "set null" }),
    actorDeviceId: uuid("actor_device_id").references(() => devices.id, { onDelete: "set null" }),
    action: text("action").notNull(),
    entityType: text("entity_type").notNull(),
    entityId: text("entity_id"),
    metadata: jsonb("metadata").default({}).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull()
  },
  (table) => ({ actorUserIdx: index("audit_events_actor_user_id_idx").on(table.actorUserId) })
);

export const userRelations = relations(users, ({ many }) => ({
  devices: many(devices),
  sessions: many(sessions)
}));

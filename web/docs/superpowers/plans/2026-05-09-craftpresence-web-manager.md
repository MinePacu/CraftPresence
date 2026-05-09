# CraftPresence Web Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Docker-runnable web manager for CraftPresence devices, Discord image assets, backups, Presence history, and cross-device Presence synchronization.

**Architecture:** Use a TypeScript monorepo with a React/Vite client, Fastify API server, PostgreSQL database, local file-backed image storage, shared Zod schemas, and WebSocket-based device synchronization. Keep user data isolated by `userId`, and make platform support extensible beyond the initial `macOS`, `iOS`, and `Android` targets.

**Tech Stack:** TypeScript, pnpm workspaces, React, Vite, Fastify, PostgreSQL, Drizzle ORM, Zod, Vitest, Playwright, Docker Compose.

---

## File Structure

Create this structure under `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web`:

```text
apps/
  client/
    index.html
    package.json
    vite.config.ts
    src/
      main.tsx
      app/App.tsx
      app/routes.tsx
      app/queryClient.ts
      api/client.ts
      auth/AuthProvider.tsx
      components/AppShell.tsx
      components/ConfirmDialog.tsx
      components/EmptyState.tsx
      components/Field.tsx
      components/JsonEditor.tsx
      components/CopyButton.tsx
      components/AssetPicker.tsx
      pages/SetupPage.tsx
      pages/LoginPage.tsx
      pages/DashboardPage.tsx
      pages/DevicesPage.tsx
      pages/AssetsPage.tsx
      pages/BackupsPage.tsx
      pages/BackupDetailPage.tsx
      pages/HistoryPage.tsx
      styles.css
  server/
    package.json
    src/
      main.ts
      app.ts
      config/env.ts
      db/client.ts
      db/schema.ts
      db/migrate.ts
      db/seed.ts
      plugins/errorHandler.ts
      plugins/auth.ts
      auth/password.ts
      auth/session.ts
      auth/routes.ts
      users/routes.ts
      devices/deviceService.ts
      devices/routes.ts
      assets/imageAssetService.ts
      assets/routes.ts
      storage/localFileStore.ts
      backups/backupService.ts
      backups/routes.ts
      presence/presenceResolver.ts
      presence/presenceService.ts
      presence/routes.ts
      realtime/deviceHub.ts
      realtime/routes.ts
      audit/auditService.ts
      tests/helpers.ts
      tests/auth.test.ts
      tests/devices.test.ts
      tests/imageAssets.test.ts
      tests/backups.test.ts
      tests/presenceResolver.test.ts
      tests/realtime.test.ts
packages/
  shared/
    package.json
    src/
      index.ts
      auth.ts
      backup.ts
      device.ts
      asset.ts
      platform.ts
      presence.ts
      user.ts
docker/
  postgres-init.sql
.dockerignore
.env.example
.gitignore
Dockerfile
docker-compose.yml
drizzle.config.ts
package.json
pnpm-workspace.yaml
tsconfig.base.json
vitest.config.ts
```

---

## Task 1: Workspace, Tooling, and Docker Skeleton

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/package.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/pnpm-workspace.yaml`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/tsconfig.base.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/vitest.config.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/.env.example`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/.gitignore`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/.dockerignore`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/Dockerfile`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/docker-compose.yml`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/docker/postgres-init.sql`

- [ ] **Step 1: Create the root package configuration**

Use this root `package.json`:

```json
{
  "name": "craftpresence-web",
  "private": true,
  "packageManager": "pnpm@9.15.0",
  "scripts": {
    "dev": "pnpm --parallel --filter @craftpresence/server --filter @craftpresence/client dev",
    "build": "pnpm -r build",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "tsc -b --pretty false",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "pnpm --filter @craftpresence/server db:migrate"
  },
  "devDependencies": {
    "@types/node": "^22.15.0",
    "drizzle-kit": "^0.30.6",
    "tsx": "^4.19.4",
    "typescript": "^5.8.3",
    "vitest": "^3.1.3"
  }
}
```

- [ ] **Step 2: Add workspace and TypeScript config**

Use this `pnpm-workspace.yaml`:

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

Use this `tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "baseUrl": ".",
    "paths": {
      "@craftpresence/shared": ["packages/shared/src/index.ts"]
    }
  }
}
```

- [ ] **Step 3: Add environment defaults**

Use this `.env.example`:

```env
NODE_ENV=development
HOST=0.0.0.0
PORT=8080
DATABASE_URL=postgres://craftpresence:craftpresence@postgres:5432/craftpresence
SESSION_SECRET=replace-with-at-least-32-random-characters
DEVICE_TOKEN_PEPPER=replace-with-at-least-32-random-characters
COOKIE_SECURE=false
IMAGE_STORAGE_PATH=/app/data/images
```

- [ ] **Step 4: Add Docker Compose**

Use this `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: craftpresence
      POSTGRES_PASSWORD: craftpresence
      POSTGRES_DB: craftpresence
    volumes:
      - craftpresence_postgres:/var/lib/postgresql/data
      - ./docker/postgres-init.sql:/docker-entrypoint-initdb.d/postgres-init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U craftpresence -d craftpresence"]
      interval: 5s
      timeout: 3s
      retries: 20

  web:
    build: .
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      NODE_ENV: production
      HOST: 0.0.0.0
      PORT: 8080
      DATABASE_URL: postgres://craftpresence:craftpresence@postgres:5432/craftpresence
      SESSION_SECRET: replace-with-at-least-32-random-characters
      DEVICE_TOKEN_PEPPER: replace-with-at-least-32-random-characters
      COOKIE_SECURE: "false"
      IMAGE_STORAGE_PATH: /app/data/images
    ports:
      - "8080:8080"
    volumes:
      - craftpresence_images:/app/data/images

volumes:
  craftpresence_postgres:
  craftpresence_images:
```

- [ ] **Step 5: Add Dockerfile**

Use a multi-stage Dockerfile that installs dependencies, builds shared/server/client packages, then runs `node apps/server/dist/main.js`.

- [ ] **Step 6: Verify workspace install**

Run:

```bash
pnpm install
pnpm lint
```

Expected: install succeeds; lint may fail only until package files exist in later tasks. After Task 3 it must pass.

---

## Task 2: Shared Schemas

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/package.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/tsconfig.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/platform.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/device.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/asset.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/presence.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/backup.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/auth.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/user.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/packages/shared/src/index.ts`

- [ ] **Step 1: Add package config**

`packages/shared/package.json`:

```json
{
  "name": "@craftpresence/shared",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "lint": "tsc -p tsconfig.json --noEmit"
  },
  "dependencies": {
    "zod": "^3.24.4"
  },
  "devDependencies": {
    "typescript": "^5.8.3"
  }
}
```

- [ ] **Step 2: Define platform and device schemas**

`platform.ts` must export:

```ts
import { z } from "zod";

export const platformSchema = z.enum(["macOS", "iOS", "Android", "Windows", "Linux"]);
export type Platform = z.infer<typeof platformSchema>;
```

`device.ts` must export schemas for `DeviceStatus`, `Device`, `CreateDeviceInput`, and `UpdateDeviceInput`. Include fields `id`, `userId`, `name`, `platform`, `priority`, `status`, `lastSeenAt`, `createdAt`, and `updatedAt`.

- [ ] **Step 3: Define Presence schemas**

`presence.ts` must support the existing app activity fields:

```ts
export const activityTypeSchema = z.enum([
  "playing",
  "streaming",
  "listening",
  "watching",
  "customStatus",
  "competing",
  "hangStatus"
]);
```

The exported `presencePayloadSchema` must include `name`, `state`, `details`, image asset fields, party fields, timestamp fields, and `activityType`.

- [ ] **Step 4: Define Discord image asset schemas**

`asset.ts` must export:

```ts
import { z } from "zod";

export const discordImageRoleSchema = z.enum(["large", "small", "both"]);

export const imageAssetSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
  title: z.string().min(1),
  key: z.string().regex(/^[a-z0-9_-]{2,64}$/),
  imageText: z.string().max(128).default(""),
  role: discordImageRoleSchema.default("both"),
  originalFilename: z.string(),
  mimeType: z.enum(["image/png", "image/jpeg", "image/webp"]),
  byteSize: z.number().int().positive(),
  width: z.number().int().positive().nullable(),
  height: z.number().int().positive().nullable(),
  createdAt: z.string(),
  updatedAt: z.string()
});

export const createImageAssetInputSchema = z.object({
  title: z.string().min(1).max(80),
  key: z.string().regex(/^[a-z0-9_-]{2,64}$/).optional(),
  imageText: z.string().max(128).optional(),
  role: discordImageRoleSchema.optional()
});

export const updateImageAssetInputSchema = createImageAssetInputSchema.partial();
```

Also export `generateDiscordAssetKey(titleOrFilename)` that lowercases, trims, replaces non-alphanumeric runs with `_`, removes leading/trailing separators, and returns a 64-character maximum key. If the result is shorter than 2 characters, prefix it with `asset_`.

- [ ] **Step 5: Define settings backup schemas**

`backup.ts` must validate the current backup shape from the existing apps:

```ts
export const settingsBackupFileSchema = z.object({
  schemaVersion: z.number().int().min(1),
  appName: z.string().default("CraftPresence"),
  appVersion: z.string().nullable().optional(),
  buildNumber: z.string().nullable().optional(),
  exportedAt: z.string(),
  platform: z.union([platformSchema, z.literal("legacy")]),
  settings: appSettingsSchema,
  platformExtensions: z.record(z.unknown()).default({})
});
```

Also export `summarizeSettingsBackup(backup)` returning `schemaVersion`, `platform`, `exportedAt`, `presetCount`, `trackedProgramCount`, and `language`.

- [ ] **Step 6: Export all schemas**

`index.ts` must re-export every schema and type from the package.

- [ ] **Step 7: Verify shared package**

Run:

```bash
pnpm --filter @craftpresence/shared build
```

Expected: TypeScript build succeeds.

---

## Task 3: Server Foundation and Database Schema

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/package.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/tsconfig.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/main.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/app.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/config/env.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/db/client.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/db/schema.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/db/migrate.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/storage/localFileStore.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/plugins/errorHandler.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/drizzle.config.ts`

- [ ] **Step 1: Add server package**

Dependencies: `@fastify/cookie`, `@fastify/multipart`, `@fastify/static`, `@fastify/websocket`, `@node-rs/argon2`, `drizzle-orm`, `fastify`, `file-type`, `image-size`, `pg`, `zod`, `@craftpresence/shared`.

- [ ] **Step 2: Add environment parser**

`env.ts` must parse and export `NODE_ENV`, `HOST`, `PORT`, `DATABASE_URL`, `SESSION_SECRET`, `DEVICE_TOKEN_PEPPER`, `COOKIE_SECURE`, and `IMAGE_STORAGE_PATH`.

- [ ] **Step 3: Add Drizzle schema**

`schema.ts` must define:

```text
users
sessions
devices
deviceTokens
settingsBackups
imageAssets
presenceEvents
currentPresence
auditEvents
```

Every user-owned table must include `userId`. Add indexes on `devices.userId`, `settingsBackups.userId`, `imageAssets.userId`, `imageAssets.key`, `presenceEvents.userId`, and `presenceEvents.deviceId`.

`imageAssets` must include:

```text
id
userId
title
key
imageText
role
originalFilename
mimeType
byteSize
width
height
storagePath
sha256
createdAt
updatedAt
```

Add a unique constraint on `(userId, key)` so each account has stable Discord image keys.

- [ ] **Step 4: Add app bootstrap**

`app.ts` must register cookie support, multipart upload support, error handler, auth plugin, all route modules, websocket routes, and static client serving when `apps/client/dist` exists.

- [ ] **Step 5: Add local image file store**

`localFileStore.ts` must write uploaded images under `IMAGE_STORAGE_PATH/<userId>/<assetId>.<extension>`, create directories recursively, compute SHA-256 while saving, and expose `saveImageFile`, `deleteImageFile`, and `resolveImagePath`.

- [ ] **Step 6: Add migration command**

`db/migrate.ts` must run Drizzle migrations against `DATABASE_URL`. `drizzle.config.ts` must point at `apps/server/src/db/schema.ts`.

- [ ] **Step 7: Verify server skeleton**

Run:

```bash
pnpm --filter @craftpresence/server build
```

Expected: TypeScript build succeeds.

---

## Task 4: Auth, Setup, and User Isolation

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/auth/password.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/auth/session.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/auth/routes.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/plugins/auth.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/users/routes.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/tests/auth.test.ts`

- [ ] **Step 1: Implement password hashing**

`password.ts` must export `hashPassword(password)` and `verifyPassword(hash, password)` using Argon2id.

- [ ] **Step 2: Implement session management**

`session.ts` must create cryptographically random session IDs, store only the hash in `sessions`, set an HttpOnly cookie named `craftpresence_session`, and delete sessions on logout.

- [ ] **Step 3: Implement setup routes**

`POST /api/setup` creates the first admin only when no users exist. `GET /api/setup/status` returns `{ requiresSetup: boolean }`.

- [ ] **Step 4: Implement auth routes**

Add:

```text
POST /api/auth/login
POST /api/auth/logout
GET  /api/me
```

All successful responses must omit password hash fields.

- [ ] **Step 5: Enforce user isolation**

`plugins/auth.ts` must decorate requests with `request.currentUser`. Protected routes must reject missing sessions with HTTP 401.

- [ ] **Step 6: Test auth**

Tests must cover:

```text
first setup succeeds
second setup fails
login succeeds with correct password
login fails with wrong password
/api/me returns the current user
logout invalidates the session
```

Run:

```bash
pnpm test apps/server/src/tests/auth.test.ts
```

Expected: all auth tests pass.

---

## Task 5: Device Management and Priority Ordering

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/devices/deviceService.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/devices/routes.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/tests/devices.test.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/DevicesPage.tsx`

- [ ] **Step 1: Implement device service**

`deviceService.ts` must expose:

```ts
createDevice(userId, input)
listDevices(userId)
updateDevice(userId, deviceId, input)
deleteDevice(userId, deviceId)
replaceDevicePriorities(userId, orderedDeviceIds)
issueDeviceToken(userId, deviceId)
revokeDeviceToken(userId, deviceId)
```

`issueDeviceToken` must return the raw token once and store only a hash with `DEVICE_TOKEN_PEPPER`.

- [ ] **Step 2: Implement device routes**

Add:

```text
GET    /api/devices
POST   /api/devices
PATCH  /api/devices/:id
DELETE /api/devices/:id
PUT    /api/devices/priorities
POST   /api/devices/:id/token
DELETE /api/devices/:id/token
```

- [ ] **Step 3: Validate priority changes**

`replaceDevicePriorities` must reject unknown IDs and IDs owned by another user. Priorities must be normalized to `1, 2, 3...`.

- [ ] **Step 4: Test device isolation**

Tests must cover:

```text
user can list only own devices
user cannot update another user's device
priority replacement normalizes values
device token is returned once and stored hashed
revoked token no longer authenticates device API
```

- [ ] **Step 5: Add initial Devices UI**

`DevicesPage.tsx` must support listing, creating, editing name/platform, deleting, issuing token, revoking token, and reordering priority with up/down buttons.

---

## Task 6: Discord Image Asset Repository

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/assets/imageAssetService.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/assets/routes.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/tests/imageAssets.test.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/CopyButton.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/AssetPicker.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/AssetsPage.tsx`

- [ ] **Step 1: Implement image asset service**

`imageAssetService.ts` must expose:

```ts
createImageAsset(userId, metadata, uploadedFile)
listImageAssets(userId, filters)
getImageAsset(userId, assetId)
updateImageAsset(userId, assetId, input)
deleteImageAsset(userId, assetId)
readImageAssetFile(userId, assetId)
buildDiscordFieldSnippet(asset, role)
```

`createImageAsset` must generate `key` with `generateDiscordAssetKey` when the user does not provide one. It must reject duplicate keys within the same user account and accept only PNG, JPEG, or WebP files. The first version stores images locally; it does not upload images to Discord Developer Portal. The generated key is the value CraftPresence should use in `largeImageKey` or `smallImageKey` after the corresponding Discord application asset exists.

- [ ] **Step 2: Implement image asset routes**

Add session-authenticated management routes:

```text
GET    /api/assets
POST   /api/assets
GET    /api/assets/:id
PATCH  /api/assets/:id
DELETE /api/assets/:id
GET    /api/assets/:id/image
POST   /api/assets/:id/snippet
```

`POST /api/assets` must accept multipart upload fields `file`, `title`, `key`, `imageText`, and `role`. `POST /api/assets/:id/snippet` must accept `{ "role": "large" | "small" }` and return:

```json
{
  "largeImageKey": "generated_key",
  "largeImageText": "Readable text"
}
```

or:

```json
{
  "smallImageKey": "generated_key",
  "smallImageText": "Readable text"
}
```

- [ ] **Step 3: Add device asset export API**

Add device-token authenticated route:

```text
GET /api/device/assets
```

The response must include asset `id`, `title`, `key`, `imageText`, `role`, `imageUrl`, and ready-to-apply snippets for both large and small image fields. Apps can use this route to populate local text fields or copy values into platform UI.

- [ ] **Step 4: Build copy controls**

`CopyButton.tsx` must use `navigator.clipboard.writeText` when available and fall back to a selected hidden textarea when clipboard access is unavailable. It must show copied/error states without requiring page reload.

- [ ] **Step 5: Build asset picker**

`AssetPicker.tsx` must list image assets, preview thumbnails, show `key` and `imageText`, and expose actions:

```text
copy key
copy image text
copy large image field JSON
copy small image field JSON
apply as large image
apply as small image
```

The apply actions must call a parent callback with `{ largeImageKey, largeImageText }` or `{ smallImageKey, smallImageText }`.

- [ ] **Step 6: Build asset library page**

`AssetsPage.tsx` must support image upload, key auto-generation preview, key override, image text editing, role selection, thumbnail preview, delete, and copy actions. It must include a short compatibility note that the key should match the Discord application asset key used by the native app's Discord SDK configuration.

- [ ] **Step 7: Test image asset behavior**

Tests must cover:

```text
image upload creates a stable generated key
duplicate key is rejected per user
different users can use the same key
unsupported MIME type is rejected
asset image route cannot read another user's image
device asset export requires a valid device token
snippet endpoint returns correct large and small field names
delete removes the database row and stored image file
```

---

## Task 7: Settings Backup Remote Management

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/backups/backupService.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/backups/routes.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/tests/backups.test.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/JsonEditor.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/BackupsPage.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/BackupDetailPage.tsx`

- [ ] **Step 1: Implement backup validation**

`backupService.ts` must parse backups with `settingsBackupFileSchema`. It must reject unsupported platform values and unsupported schema versions. Store both `rawJson` and `summary`.

- [ ] **Step 2: Implement backup routes**

Add:

```text
GET    /api/backups
POST   /api/backups/upload
GET    /api/backups/:id
PATCH  /api/backups/:id
DELETE /api/backups/:id
```

`PATCH` must validate the edited JSON before saving.

- [ ] **Step 3: Add backup list UI**

`BackupsPage.tsx` must show platform, exported time, linked device, preset count, tracked program count, and last updated time.

- [ ] **Step 4: Add backup detail UI**

`BackupDetailPage.tsx` must provide:

```text
summary tab
presence presets editor
tracked programs editor
asset picker controls for large/small image fields
raw JSON editor
delete action
save action with validation errors
```

- [ ] **Step 5: Test backup behavior**

Tests must cover:

```text
valid CraftPresence backup uploads
legacy raw AppSettings JSON is accepted as legacy
duplicate preset IDs are rejected
activePresencePresetID referencing a missing preset is rejected
user cannot read another user's backup
edited raw JSON is validated before persistence
```

---

## Task 8: Presence Events, Resolver, and History

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/presence/presenceResolver.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/presence/presenceService.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/presence/routes.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/tests/presenceResolver.test.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/DashboardPage.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/HistoryPage.tsx`

- [ ] **Step 1: Implement resolver**

`presenceResolver.ts` must export `resolvePresenceCandidate(devices, currentPresence, incomingEvent)`. Rules:

```text
disabled devices never win
online higher-priority devices win over lower-priority devices
same device latest event wins
if no current Presence exists, incoming valid event wins
if incoming does not win, store it as ignored with reason
```

- [ ] **Step 2: Implement event ingestion**

`presenceService.ts` must expose:

```ts
recordPresenceEvent(userId, deviceId, payload)
getCurrentPresence(userId)
listPresenceEvents(userId, filters)
```

When an event wins, update `currentPresence`.

- [ ] **Step 3: Implement routes**

Add session-authenticated management routes:

```text
GET /api/presence/current
GET /api/presence/events
```

Add device-token route:

```text
POST /api/device/presence-events
```

- [ ] **Step 4: Test resolver edge cases**

Tests must cover:

```text
higher-priority online device blocks lower-priority event
lower-priority device wins when higher-priority devices are offline
same device update replaces its previous current Presence
ignored events are still queryable in history
events are scoped by user
```

- [ ] **Step 5: Add dashboard and history UI**

`DashboardPage.tsx` must show current Presence, source device, recent events, and online device count. `HistoryPage.tsx` must support all-device view, device filter, platform filter, and applied/ignored filter.

---

## Task 9: Realtime Device Synchronization

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/realtime/deviceHub.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/realtime/routes.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/tests/realtime.test.ts`

- [ ] **Step 1: Implement device hub**

`deviceHub.ts` must track connected devices by `userId` and `deviceId`. It must expose:

```ts
registerConnection(userId, deviceId, socket)
unregisterConnection(userId, deviceId, socket)
broadcastPresence(userId, originDeviceId, message)
markDeviceOnline(deviceId)
markDeviceOffline(deviceId)
```

- [ ] **Step 2: Add device websocket route**

Add:

```text
GET /api/device/realtime?token=<device-token>
```

Authentication must use the same hashed token lookup as device REST routes.

- [ ] **Step 3: Broadcast winning Presence**

After `recordPresenceEvent` updates `currentPresence`, call `broadcastPresence`. Do not send the update back to the origin device.

- [ ] **Step 4: Support bootstrap on reconnect**

Add:

```text
GET /api/device/bootstrap
```

Device-token authenticated response must include current Presence, device metadata, and server time.

- [ ] **Step 5: Test realtime**

Tests must cover:

```text
valid token opens websocket
invalid token is rejected
winning Presence is broadcast to other devices
origin device does not receive its own Presence event
offline device can fetch current Presence from bootstrap
```

---

## Task 10: Client App Foundation

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/package.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/tsconfig.json`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/vite.config.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/index.html`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/main.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/app/App.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/app/routes.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/app/queryClient.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/api/client.ts`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/auth/AuthProvider.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/AppShell.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/ConfirmDialog.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/EmptyState.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/Field.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/components/CopyButton.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/styles.css`

- [ ] **Step 1: Add client package**

Dependencies: `@tanstack/react-query`, `@vitejs/plugin-react`, `lucide-react`, `react`, `react-dom`, `react-router-dom`, `zod`, `@craftpresence/shared`.

- [ ] **Step 2: Add API client**

`api/client.ts` must wrap `fetch`, send cookies, parse JSON, and throw typed errors with `status` and `message`.

- [ ] **Step 3: Add auth provider**

`AuthProvider.tsx` must load `/api/me`, expose `user`, `requiresSetup`, `login`, `logout`, and `refresh`.

- [ ] **Step 4: Add routes**

Routes:

```text
/setup
/login
/
/devices
/assets
/backups
/backups/:id
/history
```

Unauthenticated users go to `/login`; fresh installs go to `/setup`.

- [ ] **Step 5: Add app shell**

`AppShell.tsx` must include navigation for Dashboard, Devices, Assets, Backups, History, and Logout. Keep layout dense and operational rather than landing-page style.

---

## Task 11: Setup, Login, and Management UI Pages

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/SetupPage.tsx`
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/LoginPage.tsx`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/DashboardPage.tsx`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/DevicesPage.tsx`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/AssetsPage.tsx`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/BackupsPage.tsx`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/BackupDetailPage.tsx`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/src/pages/HistoryPage.tsx`

- [ ] **Step 1: Build setup page**

Fields: display name, email, password, confirm password. Submit to `POST /api/setup`. On success, route to `/`.

- [ ] **Step 2: Build login page**

Fields: email and password. Submit to `POST /api/auth/login`. On success, route to `/`.

- [ ] **Step 3: Complete dashboard**

Show current Presence, source device, last update time, online/offline count, recent five events, and quick links to device priority, image assets, and backups.

- [ ] **Step 4: Complete devices page**

Support create, edit, delete, token issue/revoke, priority up/down, and status badge. Show one-time device token in a dismissible dialog.

- [ ] **Step 5: Complete backups pages**

Support upload by file picker, list summaries, edit structured sections, edit raw JSON, save, and delete. Presence preset and tracked program editors must include `AssetPicker` controls next to `largeImageKey`, `largeImageText`, `smallImageKey`, and `smallImageText` so a stored asset can fill those fields.

- [ ] **Step 6: Complete assets page**

Support upload, edit, delete, thumbnail preview, generated key display, large/small snippet preview, and clipboard copy for key/text/snippets.

- [ ] **Step 7: Complete history page**

Support filters and readable Presence event rows. Each row must show device, platform, applied/ignored, reason, and payload summary.

---

## Task 12: Audit Events and Operational Safety

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/audit/auditService.ts`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/auth/routes.ts`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/devices/routes.ts`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/assets/routes.ts`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/backups/routes.ts`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/server/src/presence/routes.ts`

- [ ] **Step 1: Implement audit service**

`auditService.ts` must write `actorUserId`, `actorDeviceId`, `action`, `entityType`, `entityId`, and metadata.

- [ ] **Step 2: Record critical actions**

Record audit events for login, logout, device creation, device deletion, priority changes, token issue/revoke, image asset upload, image asset update, image asset deletion, backup upload, backup update, backup deletion, and Presence application.

- [ ] **Step 3: Keep audit internal**

Do not expose audit UI in the first version. Keep the table available for debugging and future admin pages.

---

## Task 13: End-to-End Verification and Docker Run

**Files:**
- Create: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/apps/client/tests/app.spec.ts`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/package.json`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/Dockerfile`
- Modify: `/Users/nohyunsoo/Desktop/projects/CraftPresence-work/web/docker-compose.yml`

- [ ] **Step 1: Add Playwright**

Add `@playwright/test` and script:

```json
{
  "scripts": {
    "test:e2e": "playwright test"
  }
}
```

- [ ] **Step 2: Add E2E flow**

`app.spec.ts` must cover:

```text
setup first admin
login
create device
change priority
upload image asset
copy generated asset key
upload valid backup
view backup detail
apply stored asset to a backup Presence image field
submit Presence event using device token
confirm dashboard current Presence updates
confirm history shows the event
```

- [ ] **Step 3: Verify production build**

Run:

```bash
pnpm install
pnpm build
pnpm test
docker compose up --build
```

Expected:

```text
server listens on http://localhost:8080
/setup appears on first install
PostgreSQL health check passes
web container remains running
```

- [ ] **Step 4: Verify API from outside the UI**

Use the issued device token to call:

```bash
curl -H "Authorization: Bearer <device-token>" http://localhost:8080/api/device/bootstrap
```

Expected: response includes `device`, `currentPresence`, and `serverTime`.

---

## Implementation Order

Build in this order:

```text
Task 1 -> Task 2 -> Task 3 -> Task 4 -> Task 5 -> Task 6 -> Task 8 -> Task 9 -> Task 7 -> Task 10 -> Task 11 -> Task 12 -> Task 13
```

Reasoning:

```text
shared schemas first
auth before user-owned data
devices before Presence priority
image assets before backup UI field pickers
Presence resolver before realtime
backups after core device model
UI after API contracts stabilize
Docker verification last
```

---

## Acceptance Criteria

- Docker Compose starts PostgreSQL and the web app.
- First install shows setup, and setup creates the first admin.
- Login, logout, and session persistence work.
- Each account sees only its own devices, backups, and Presence events.
- Devices can be created, removed, tokenized, and prioritized.
- Image assets can be uploaded, stored, previewed, renamed, assigned Discord-compatible keys/text, copied to clipboard, exported to device clients, and deleted.
- Backup and Presence editors can fill `largeImageKey`, `largeImageText`, `smallImageKey`, and `smallImageText` from stored image assets.
- Backup JSON compatible with current CraftPresence app schema can be uploaded, edited, validated, and deleted.
- Presence events can be recorded globally and per device.
- Current Presence is selected by priority rules.
- Winning Presence is broadcast to other connected devices, excluding the origin device.
- Offline devices can fetch current Presence on reconnect.
- Windows and Linux are accepted at schema level for future app support.
- Unit and E2E tests cover auth, device isolation, image asset storage/export, backup validation, Presence resolution, realtime sync, and the main UI flow.

# CraftPresence Android UX Redesign

Figma file created: https://www.figma.com/design/ykjlgxdEnFLi8mAEg5XvbL

Figma MCP write access hit the Starter plan tool-call limit after file creation, so this document records the redesign direction and screen structure to place into the Figma file when calls are available again.

## Design Goals

- Make Android setup as direct as iOS by exposing the next required action instead of hiding it in subpages.
- Treat Android Settings handoffs as first-class UX: explain where the user is going, why, and what to do after returning.
- Keep setup status visible across Overview, Settings, Permissions, and App registration.
- Reduce repeated cards by grouping controls into clear task sections.
- Preserve the current Material 3 implementation direction and CraftPresence palette.

## Current UX Issues

- Settings home mixes general preferences and navigation actions, so Discord, apps, and permissions feel secondary.
- Permission cards provide buttons, but the Android destination and return flow are not explicit enough.
- App registration is split between current app, installed app picker, and registered app rows, which makes the main task slower than necessary.
- Overview has useful state, but the primary next action can be made more prominent and reusable across setup flows.

## Proposed Information Architecture

Bottom navigation remains:

- Overview
- Presence
- Music
- Settings

Settings becomes a task hub with four destination rows:

- Discord account
- Tracked apps
- Permissions
- Backup and restore

Each destination row should include:

- icon
- title
- one-line status
- right-side status chip or chevron

## Screen Set

### 1. Overview

Purpose: show app health and the single next best action.

Sections:

- Header: CraftPresence + short subtitle.
- Next best action card:
  - Example: "Allow Usage Access"
  - Detail: "Needed to detect the foreground app for app-based presence."
  - Primary button: "Open Android settings"
- Status metrics:
  - Discord: Ready
  - Apps: 3 tracked
  - Music: Standby
- Live Presence card:
  - Current app
  - Music source
- Quick shortcuts:
  - Discord account
  - Apps to track
  - Permissions

### 2. Settings Home

Purpose: replace the current loose action buttons with a structured settings hub.

Sections:

- Setup Health card:
  - "2 permissions granted. Notification listener still needs Android Settings."
  - Primary button: "Continue setup"
- Settings Destinations:
  - Discord: Account, Application ID, reconnect
  - Tracked apps: Register apps and edit presets
  - Permissions: Usage, notification, listener access
  - Backup: Import and export JSON settings
- Preferences:
  - Foreground app banner
  - Foreground notification
  - Discord auto-connect
  - Reset elapsed time
  - Language

### 3. Permissions

Purpose: make Android permission handoff explicit.

Sections:

- Required Next Step card:
  - Title: "Notification listener access"
  - Body: "Android will open Notification access. Choose CraftPresence, allow access, then return here."
  - Primary button: "Open Notification access"
- Permission Checklist:
  - Usage access: Granted
  - App notifications: Granted
  - Notification listener: Required
  - Secondary button: "Refresh status"
- Why this is needed:
  - Android separates permissions into different Settings screens, so each action names the exact destination.

### 4. Tracked Apps

Purpose: combine current foreground app, installed-app search, and registered apps.

Sections:

- Current App:
  - App name
  - Package name
  - Primary button: "Add current app"
- Installed App Search:
  - Search field
  - System apps toggle
- Registered Apps:
  - App icon or initial
  - Display name
  - Presence preset status
  - Edit action

### 5. Presence Editor

Purpose: keep preview visible before advanced fields.

Sections:

- Discord Preview:
  - Activity title
  - Detail
  - State
  - elapsed time
  - Save button
- Presence Source:
  - Selected app
  - Activity type
- Core Fields:
  - Display name
  - Detail text
  - State text
  - Images
- Advanced Fields:
  - timestamps
  - party size
  - image hover text

### 6. Music

Purpose: clarify global platform state and active playback.

Sections:

- Now Playing:
  - active platform
  - track state
  - artwork preview when available
- Music Platforms:
  - Apple Music
  - Spotify
  - YouTube Music
  - per-platform enable/stop
- Bulk actions:
  - Start all
  - Stop all
- How it works:
  - media session monitoring
  - artwork lookup
  - Discord music presence

## Component Direction

- Use Material 3 card, list item, switch, button, chip, search field, navigation bar.
- Use 8 to 22dp radius depending on component role:
  - repeated rows: 16 to 18dp
  - cards: 20 to 22dp
  - buttons/chips: fully rounded
- Keep primary action cards colored with the existing `PresenceBlue` and soft blue container.
- Use status color consistently:
  - granted/running: mint
  - standby/configuring: amber
  - required/error: red
  - neutral: surface variant

## Implementation Notes For Compose

- Replace `SettingsHomeScreen` action button card with a `SettingsDestinationList`.
- Add a reusable `SetupHealthCard` used by Overview, Settings, and Permissions.
- Update `PermissionCard` to show destination context before the button.
- Consider replacing `SettingsSubpageHeader` card with a top app bar style row to reduce vertical cost.
- Keep Android Settings launch logic in `PermissionService`; only update presentation.

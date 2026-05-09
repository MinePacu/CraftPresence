# CraftPresence

[한국어](README.md) | English

CraftPresence is a multi-platform project for using Discord Rich Presence across different devices. This repository currently contains Android, macOS, and iOS apps, plus a web-based manager for administering registered CraftPresence devices from one place.

The native apps handle Discord account connection, Presence publishing, and app or user activity display on a Discord profile. The web manager acts as a server-style console for device registration, Presence priority, settings backups, Discord image assets, and Presence history.

## Project Layout

| Component | Description | Docs |
| --- | --- | --- |
| Android | Android app that detects the current foreground app and music playback state, then publishes it through Discord Rich Presence | [Android README](Android/README.en.md) |
| macOS | Native macOS app that tracks running applications and automatically updates Discord Rich Presence | [macOS README](macOS/README_EN.md) |
| iOS | SwiftUI app for creating custom Presence presets on iPhone and iPad and publishing them as Discord activity | [iOS README](iOS/README.en.md) |
| Web Manager | Docker-based web console for registered CraftPresence devices, settings backups, Discord image assets, Presence history, and synchronization state | `web/` |

## Features

- Discord account authentication and Rich Presence publishing
- Platform-specific app activity or custom Presence display
- Activity metadata such as music playback, app name, window title, and preset status
- Custom Presence text, activity type, image keys, party information, and related settings
- Settings backup JSON export, import, validation, and remote management
- Presence priority management and current Presence synchronization across registered devices
- Image asset repository for Discord Rich Presence large/small image keys and image text
- Global and per-device Presence event history
- Localized UI resources, including Korean and English
- Platform-specific permission guidance and connection status screens

## Repository Structure

```text
CraftPresence-work/
├── Android/  # Android app built with Kotlin and Jetpack Compose
├── macOS/    # macOS app built with SwiftUI
├── iOS/      # iPhone/iPad app built with SwiftUI
└── web/      # Web manager built with React, Fastify, and PostgreSQL
```

## Tech Stack

- **Android**: Kotlin, Jetpack Compose, Android SDK, Discord Partner SDK
- **macOS**: Swift, SwiftUI, Swift/C++ Interoperability, macOS Accessibility API, Discord Partner SDK
- **iOS**: Swift, SwiftUI, Discord Partner SDK
- **Web Manager**: TypeScript, React, Vite, Fastify, PostgreSQL, Drizzle ORM, Docker Compose

## Getting Started

Each platform and the web manager have their own build tools and local configuration flow. Start with the README or setup files for the directory you want to work on.

- [Android getting started](Android/README.en.md#configuration)
- [macOS getting started](macOS/README_EN.md#installation--build)
- [iOS getting started](iOS/README.en.md#getting-started)
- Web manager: `cd web && docker compose up --build`

Discord integration requires an Application ID created in the Discord Developer Portal. Real Application IDs and local configuration files should be kept out of git.

The web manager runs on `http://localhost:8080` by default. To change the host port, edit the first value in the `ports` entry in `web/docker-compose.yml`. For example, `8081:8080` exposes the console at `http://localhost:8081`.

## Development Notes

- This repository keeps platform-specific implementations in one workspace.
- Android focuses on foreground app detection and music playback based Presence.
- macOS focuses on running app tracking through Accessibility permissions and per-program Presence settings.
- iOS focuses on user-created Presence presets and manual publishing.
- Web Manager focuses on account-scoped device management, remote settings backups, image asset management, Presence event history, and cross-device Presence synchronization.
- The current native app targets are Android, macOS, and iOS. The web manager data model is structured so Windows and Linux device support can be added later.

## License

See the platform-specific license files.

- [Android LICENSE](Android/LICENSE)
- [iOS LICENSE](iOS/LICENSE)

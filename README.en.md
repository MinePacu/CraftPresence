# CraftPresence

[한국어](README.md) | English

CraftPresence is a multi-platform project for using Discord Rich Presence across different devices. This repository currently contains Android, macOS, and iOS apps. Each platform focuses on connecting a Discord account, publishing Presence, and showing app or user activity on a Discord profile.

## Project Layout

| Platform | Description | Docs |
| --- | --- | --- |
| Android | Android app that detects the current foreground app and music playback state, then publishes it through Discord Rich Presence | [Android README](Android/README.en.md) |
| macOS | Native macOS app that tracks running applications and automatically updates Discord Rich Presence | [macOS README](macOS/README_EN.md) |
| iOS | SwiftUI app for creating custom Presence presets on iPhone and iPad and publishing them as Discord activity | [iOS README](iOS/README.en.md) |

## Features

- Discord account authentication and Rich Presence publishing
- Platform-specific app activity or custom Presence display
- Activity metadata such as music playback, app name, window title, and preset status
- Custom Presence text, activity type, image keys, party information, and related settings
- Localized UI resources, including Korean and English
- Platform-specific permission guidance and connection status screens

## Repository Structure

```text
CraftPresence-work/
├── Android/  # Android app built with Kotlin and Jetpack Compose
├── macOS/    # macOS app built with SwiftUI
└── iOS/      # iPhone/iPad app built with SwiftUI
```

## Tech Stack

- **Android**: Kotlin, Jetpack Compose, Android SDK, Discord Partner SDK
- **macOS**: Swift, SwiftUI, Swift/C++ Interoperability, macOS Accessibility API, Discord Partner SDK
- **iOS**: Swift, SwiftUI, Discord Partner SDK

## Getting Started

Each platform has its own build tools and local configuration flow. Start with the README for the platform you want to work on.

- [Android getting started](Android/README.en.md#configuration)
- [macOS getting started](macOS/README_EN.md#installation--build)
- [iOS getting started](iOS/README.en.md#getting-started)

Discord integration requires an Application ID created in the Discord Developer Portal. Real Application IDs and local configuration files should be kept out of git.

## Development Notes

- This repository keeps platform-specific implementations in one workspace.
- Android focuses on foreground app detection and music playback based Presence.
- macOS focuses on running app tracking through Accessibility permissions and per-program Presence settings.
- iOS focuses on user-created Presence presets and manual publishing.

## License

See the platform-specific license files.

- [Android LICENSE](Android/LICENSE)
- [iOS LICENSE](iOS/LICENSE)

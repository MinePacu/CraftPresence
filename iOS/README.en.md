# CraftPresence

English | [한국어](README.md)

CraftPresence is a SwiftUI app for publishing custom Discord Rich Presence from iPhone and iPad. It lets users create Presence presets, authorize with Discord, and publish the selected status as their Discord activity.

## Features

- Discord Partner SDK authentication and Rich Presence publishing
- Create, edit, and delete custom Presence presets
- Configure activity type, details, state, image keys, party information, and elapsed time
- Overview dashboard for Discord connection state, authorized user, and active preset
- Korean, English, and Japanese localization resources
- Automation setting seed support for UI tests

## Project Layout

```text
CraftPresence/
├── App/                         App entry point and platform bootstrap
├── Features/
│   ├── Discord/                 Discord authentication, SDK integration, test view
│   ├── Overview/                Status dashboard
│   ├── Permissions/             Permission guidance view
│   ├── Presence/                Built-in Presence-related code
│   └── Programs/                Presence preset management UI
├── Shared/                      Shared models, settings store, localization, root view
├── ThirdParty/DiscordSocialSDK/ Discord Partner SDK XCFramework
├── en.lproj/
├── ja.lproj/
└── ko.lproj/
```

## Requirements

- macOS development environment with Xcode installed
- Swift 5 Xcode project
- iPhone or iPad simulator/device
- Discord application ID from the Discord Developer Portal

The project file currently sets the iOS deployment target to `26.4`. If that does not match your Xcode and SDK setup, adjust the deployment target in the target build settings.

## Getting Started

1. Clone the repository.

   ```bash
   git clone <repository-url>
   cd CraftPresence
   ```

2. Open `CraftPresence.xcodeproj` in Xcode.

3. Check that the `APPLICATION_ID` value in the `CraftPresence` target points to your Discord application ID.

4. In the Discord Developer Portal, make sure the redirect URI or URL scheme settings match the app schemes.

   ```text
   discord-<APPLICATION_ID>
   craftpresence
   ```

5. Select the `CraftPresence` scheme, then build and run on an iPhone or iPad target.

## Discord Configuration

The app reads `APPLICATION_ID` from `Info.plist` to configure the Discord SDK. The Xcode project wires this through the `INFOPLIST_KEY_APPLICATION_ID` build setting, so forks and release builds should use their own Discord application ID.

The `largeImageKey` and `smallImageKey` values used in Rich Presence presets must match Rich Presence asset keys registered in the Discord Developer Portal.

## Development Notes

- App settings are persisted as JSON through the `ConfigUtility` actor.
- Default presets are `Focus`, `Studying`, and `Coding`.
- `ProgramDetector` exposes an interface for active app updates, but the current implementation in this project is a stub and does not perform real detection.
- `BuildProducts/` and DerivedData contents are development artifacts. They usually do not need to be edited for documentation or source changes.

## Testing

You can run the `CraftPresenceTests` and `CraftPresenceUITests` targets from Xcode.

This environment currently has the active developer directory set to Command Line Tools, so `xcodebuild` verification was not run here. To run command-line tests locally, make sure full Xcode is selected.

## License

This project is licensed under the [MIT License](LICENSE).

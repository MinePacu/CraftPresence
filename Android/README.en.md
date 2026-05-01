# CraftPresence

[한국어](README.md) | English

CraftPresence is an Android app that sends foreground app usage and music playback status to Discord Rich Presence.

## Features

- Connect a Discord account and update Rich Presence
- Show app usage when a registered Android app is in the foreground
- Show playback status from YouTube Music, Spotify, and Apple Music
- Send track title, artist, playback start/end time, and album artwork
- Customize per-app Presence text, activity type, image key/URL, and party information
- Optional foreground app display and notification
- Korean, English, and Japanese UI strings

## Requirements

- Android Studio
- JDK 11 or later
- Android SDK 36
- Android 7.0 (API 24) or later device
- Discord app or a browser that can complete Discord login
- Application ID from the Discord Developer Portal

## Configuration

Add your Discord Application ID to `local.properties`.

```properties
DISCORD_APPLICATION_ID=123456789012345678
```

This value is used at build time for the Discord authentication redirect scheme in the Android manifest. If it is missing, the app uses the placeholder `YOUR_APPLICATION_ID` and reports the configuration as invalid.

## Build And Test

```bash
./gradlew test
./gradlew assembleDebug
```

In Android Studio, open the project and run the `app` configuration.

## Permissions

CraftPresence uses these Android permissions depending on the enabled features.

- Usage access: detects the current foreground app and updates Presence for registered apps.
- Notification access: reads now-playing metadata from music apps.
- App notifications: shows the current foreground app as an Android notification.
- Internet: communicates with the Discord SDK and fetches artwork metadata.

You can review permission status and open the related Android settings screens from the app's `Permissions` screen.

## Usage

1. Launch the app and connect your Discord account.
2. Allow the required permissions from the `Permissions` screen.
3. Register apps to track from the `Programs` screen.
4. Adjust per-app Presence text and image settings as needed.
5. Start the desired music platforms from the `Music` screen.

## Project Structure

```text
app/src/main/java/com/minepacu/craftpresence
├── core/config        # App settings and Presence settings models
├── core/discord      # Discord SDK connection and Activity models
├── core/media        # Music platforms, media sessions, artwork lookup
├── core/permissions  # Android permission status and settings intents
├── core/presence     # App/music Presence managers
├── core/programs     # Foreground app detection
└── ui                # Compose UI, theme, localized text
```

## Notes

- `app/libs/discord_partner_sdk.aar` is used for Discord Social SDK integration.
- `local.properties` stores local private settings and should not be committed.
- Per-app Presence templates can use `{app}`, `{package}`, and `{title}` placeholders.

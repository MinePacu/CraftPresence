# CraftPresence

> **English** | [**한국어**](README.md)

A macOS application that tracks running applications in real-time and automatically updates your current activity through Discord Rich Presence.

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2026.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Table of Contents
- [Introduction](#introduction)
- [Key Features](#key-features)
- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Installation & Build](#installation--build)
- [Configuration](#configuration)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Introduction

CraftPresence is a Discord Rich Presence management tool for macOS users. It automatically detects currently running applications and updates your Discord profile activity status in real-time.

### Why CraftPresence?

- **🎮 Auto Detection**: Automatically tracks running applications without manual configuration
- **⚙️ Customization**: Fine-tune Rich Presence display content for each program
- **🔒 Privacy**: Selectively track only the applications you want
- **🎨 SwiftUI**: Native macOS app built with modern SwiftUI and Swift 6.0

## Key Features

### 1. Real-time Application Tracking
- Foreground application detection using macOS Accessibility API
- Automatic recognition of application name, Bundle ID, and window title
- Instant reflection of application switching with real-time updates

### 2. Discord Rich Presence Integration
- Native integration using Discord C++ SDK
- Stable integration through Swift/C++ Interoperability
- OAuth2 authentication support
- Automatic user information retrieval

### 3. Per-Program Customization
- Save Rich Presence settings for each application
- Configure detailed settings including State, Details, images, etc.
- Data persistence with JSON-based configuration files

### 4. User-friendly Interface
- Modern UI based on SwiftUI
- Intuitive screen transitions with sidebar navigation
- Program list management and settings screens
- Built-in debug/test screens

## Screenshots

> Add actual app screenshots here

## Requirements

### System Requirements
- **macOS**: 26.0 (Sequoia) or later
- **Xcode**: 26.0.1 or later
- **Swift**: 6.0 or later

### Discord Setup
- Discord account
- Application ID created in Discord Developer Portal
- Discord application with Rich Presence feature enabled

## Installation & Build

### 1. Clone Repository

```bash
git clone https://github.com/MinePacu/CraftPresence.git
cd CraftPresence
```

### 2. Verify Discord SDK Library

The project includes Discord Partner SDK:
```
CraftPresence/ThirdParty/DIscordSDK/
├── include/
│   ├── discordpp.h
│   ├── DiscordppWrapper.hpp
│   └── DiscordppWrapper.cpp
└── lib/
    └── libdiscord_partner_sdk.dylib
```

### 3. Open Project in Xcode

```bash
open CraftPresence.xcodeproj
```

### 4. Build Project

1. Select `CraftPresence` as the target in Xcode
2. Run `Product > Build` (⌘+B)
3. Once build succeeds, run with `Product > Run` (⌘+R)

## Configuration

### Discord Application ID Setup

#### Method 1: Edit Info.plist
1. Create an Application in Discord Developer Portal
2. Copy the Application ID
3. Change the `APPLICATION_ID` key value in `CraftPresence/Info.plist`

```xml
<key>APPLICATION_ID</key>
<string>YOUR_DISCORD_APPLICATION_ID</string>
```

#### Method 2: Use Environment Variable
```bash
export APPLICATION_ID="YOUR_DISCORD_APPLICATION_ID"
```

### Grant Accessibility Permissions

The app requires Accessibility permissions to detect running applications:

1. Permission request screen appears on first launch
2. Navigate to `System Settings > Privacy & Security > Accessibility`
3. Enable CraftPresence
4. Restart the app

## Usage

### 1. Launch App and Authenticate
1. Launch CraftPresence
2. Sign in to Discord (OAuth2 authentication)
3. Grant permissions

### 2. Add Programs
1. Select "Programs" from the sidebar
2. Launch the application you want to track
3. Automatically detected or manually enter Bundle ID

### 3. Customize Rich Presence
1. Select desired app from program list
2. Configure State, Details, images, etc.
3. Changes are automatically saved

### 4. Real-time Monitoring
- Check current foreground app in Overview screen
- Verify real-time reflection on Discord profile

## Project Structure

```
CraftPresence/
├── CraftPresence/
│   ├── CraftPresenceApp.swift      # App entry point
│   ├── ContentView.swift           # Main UI
│   ├── PermissionView.swift        # Permission request UI
│   ├── Item.swift                  # Data model
│   ├── Core/
│   │   ├── DiscordSDK.swift        # Discord SDK manager
│   │   ├── ProgramDetector.swift   # Application detection
│   │   ├── ConfigUtility.swift     # Configuration management
│   │   └── PermissionService.swift # Permission management
│   ├── ThirdParty/
│   │   └── DIscordSDK/             # Discord C++ SDK
│   │       ├── include/
│   │       │   ├── discordpp.h
│   │       │   ├── DiscordppWrapper.hpp
│   │       │   └── DiscordppWrapper.cpp
│   │       ├── lib/
│   │       │   └── libdiscord_partner_sdk.dylib
│   │       └── modules/
│   │           └── module.modulemap
│   └── Assets.xcassets/
└── CraftPresenceTests/
```

## Tech Stack

### Languages & Frameworks
- **Swift 6.0**: Utilizing latest Swift concurrency features
- **SwiftUI**: Declarative UI framework
- **SwiftData**: Data persistence
- **C++20**: Discord SDK integration

### Key Libraries
- **Discord Partner SDK**: C++ native SDK
- **Swift/C++ Interoperability**: Swift-C++ bridge
- **macOS Accessibility API**: Application detection

### Architecture Patterns
- **MVVM**: Model-View-ViewModel
- **Actor Model**: Thread-safe state management
- **Async/Await**: Asynchronous task processing

## Troubleshooting

### Accessibility Permission Issues
**Symptoms**: Application detection not working

**Solutions**:
1. Check Accessibility permissions in System Settings
2. Restart the app
3. If needed, remove and re-grant permissions

### Discord Connection Failure
**Symptoms**: Discord Rich Presence not updating

**Solutions**:
1. Verify Discord app is running
2. Check if Application ID is correct
3. Verify app activation status in Discord Developer Portal
4. Check logs: Debug > Discord Test screen

### Build Errors
**Symptoms**: Linker errors or module not found

**Solutions**:
1. Clean Build Folder (⌘+Shift+K)
2. Delete Derived Data
3. Restart Xcode
4. Verify project settings:
   - Header Search Paths
   - Library Search Paths
   - Other Linker Flags

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines
- Follow Swift code style guide
- Write tests for new features
- Update documentation
- Keep commit messages clear and concise

## License

This project is distributed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For project inquiries or bug reports, please use GitHub Issues.

- **GitHub**: [MinePacu/CraftPresence](https://github.com/MinePacu/CraftPresence)
- **Issues**: [Bug Reports & Feature Requests](https://github.com/MinePacu/CraftPresence/issues)

---

**Made by MinePacu**

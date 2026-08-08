# ATV Remote - SwiftUI

Native macOS/iOS/tvOS application for controlling Apple TV devices.

## Project Structure

```
ATVRemote/
├── Packages/
│   └── ATVRemoteCore/           # Shared Swift Package
│       ├── Models/              # Data models
│       ├── Services/            # Discovery, Pairing, Connection
│       └── Protocol/            # MRP protocol implementation
├── Shared/
│   ├── Views/                   # SwiftUI views
│   └── ViewModels/              # View models
├── App/
│   └── macOS/                   # macOS app entry point
└── scripts/                     # Build scripts
```

## Setup

### Prerequisites

- Xcode 15+
- macOS 14+ / iOS 17+ / tvOS 17+
- Homebrew (for protobuf tools)

### Installation

1. **Install dependencies:**
   ```bash
   brew install protobuf swift-protobuf
   ```

2. **Generate protobuf files:**
   ```bash
   cd ATVRemote
   ./scripts/generate-protos.sh
   ```

3. **Build Swift Package:**
   ```bash
   cd Packages/ATVRemoteCore
   swift build
   ```

4. **Open in Xcode:**
   - Create new macOS App project named "ATVRemote"
   - Add local package: `Packages/ATVRemoteCore`
   - Add source files from `App/macOS/` and `Shared/`
   - Configure Info.plist with network permissions

## Architecture

### MVVM Pattern

- **Models**: `AppleTVDevice`, `PlaybackInfo`, `RemoteCommand`, `PairingCredentials`
- **ViewModels**: `DeviceListViewModel`, `RemoteControlViewModel`
- **Views**: `DeviceListView`, `RemoteControlView`, `TouchpadView`

### Services

- **DeviceDiscoveryService**: Bonjour/mDNS discovery via NWBrowser
- **PairingService**: SRP authentication with Apple TV
- **ConnectionService**: MRP protocol communication
- **CredentialsManager**: Keychain storage for pairing credentials

## Features

- [x] Device Discovery (NWBrowser)
- [x] Device List UI (native SwiftUI)
- [x] Remote Control UI (1:1 port from Vue)
- [x] Protobuf protocol definitions
- [ ] SRP Pairing
- [ ] MRP Connection
- [ ] Playback Info
- [ ] Menu bar integration (macOS)
- [ ] iOS/tvOS support

## Required Permissions

Add to `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>ATV Remote needs to discover Apple TV devices on your local network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_mediaremotetv._tcp</string>
</array>
```

## License

Private - All rights reserved

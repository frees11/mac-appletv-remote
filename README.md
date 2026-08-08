# ATV Remote

Native SwiftUI macOS app for controlling Apple TV devices. Discovery, Companion
pairing, remote control (HID), now-playing — implemented in
`ATVRemote/Packages/ATVRemoteCore`.

## Quick start

```bash
xcodebuild -project "ATVRemote/ATV Remote.xcodeproj" -scheme "ATV Remote" \
  -configuration Debug -destination "platform=macOS" \
  -derivedDataPath build/DerivedData build
open "build/DerivedData/Build/Products/Debug/ATV Remote.app"
```

Details: [ATVRemote/README.md](ATVRemote/README.md). Contributor guide:
[AGENTS.md](AGENTS.md).

## Development target

`tools/fake-atv/` publishes a fake Apple TV on the LAN so you can develop
without touching real TVs (pairing PIN 1111):

```bash
tools/fake-atv/setup.sh              # once
tools/fake-atv/run.sh --demo --daemon -d
```

## Legacy

The previous Electron + Vue implementation lives in
`../mac-appletv-remote-electron` (full git history) and serves as a design
reference only.

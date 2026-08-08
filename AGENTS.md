# Repository Guidelines

## Project Structure & Module Organization

This repository contains the native SwiftUI macOS app for controlling Apple TV devices:

- `ATVRemote/`: the app — Xcode project (`ATV Remote.xcodeproj`, scheme `ATV Remote`), shared Swift package (`Packages/ATVRemoteCore`), and XCTest/UI test targets.
- `ATVRemote/Packages/ATVRemoteCore/`: models, discovery/pairing/connection services, and the MRP protocol implementation.
- `tools/fake-atv/`: fake Apple TV published on the LAN for development — see its README and HANDOVER for setup and verified pitfalls. Companion pairing PIN is 1111.
- Generated output lives in `ATVRemote/Packages/*/.build/`, `ATVRemote/build/`, and `build/DerivedData/`; do not hand-edit or commit generated files.

The legacy Electron + Vue + Python/Node backend implementation was moved to
`../mac-appletv-remote-electron` (full git history preserved). Use it only as a
design and interaction reference; do not develop there.

## Build, Test, and Development Commands

- `cd ATVRemote/Packages/ATVRemoteCore && swift build`: build the shared Swift package.
- `xcodebuild -project "ATVRemote/ATV Remote.xcodeproj" -scheme "ATV Remote" -configuration Debug -destination "platform=macOS" -derivedDataPath build/DerivedData build`: build the app.
- `open "build/DerivedData/Build/Products/Debug/ATV Remote.app"`: launch the built app.
- `xcodebuild test -project "ATVRemote/ATV Remote.xcodeproj" -scheme "ATV Remote" -destination "platform=macOS"`: run native unit and UI tests.
- `tools/fake-atv/setup.sh` once, then `tools/fake-atv/run.sh --demo --daemon -d`: run the fake Apple TV dev target with debug logging.

## Coding Style & Naming Conventions

Use 4-space indentation in Swift. Keep SwiftUI views in `PascalCase`
(`DeviceListView.swift`), tests in `*Tests.swift`. Follow the structure already
present in `ATVRemoteCore` (Models / Services / Protocol). Make focused diffs.

## Testing Guidelines

Swift tests use `XCTest` with `ViewInspector`; place them in
`ATVRemote/ATVRemoteTests` or `ATVRemote/ATVRemoteUITests`. Prefer testing
against `tools/fake-atv` instead of real Apple TVs — real TVs show a pairing
dialog on screen and may be in use.

## Commit & Pull Request Guidelines

History follows Conventional Commit prefixes (`feat:`, `fix:`, `chore:`) with
lowercase summaries. Keep commits scoped to one concern. PRs should list the
verification commands run and include screenshots or recordings for UI changes.

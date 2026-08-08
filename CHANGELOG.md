# Changelog

All notable changes to ATV Remote Pro are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versions up to and including 1.0.9 refer to the Electron application, which now
lives in a separate repository. Everything from 1.0.10 onwards is the native
SwiftUI rewrite.

## [Unreleased]

### Added
- Subscriptions: StoreKit 2 service, protocol and mock in `ATVRemoteCore`, plus a
  paywall gating the app. Pro Yearly carries a 2-month free trial.
- Demo mode — runs the app against the mock services so App Review can see every
  screen without an Apple TV on the network.
- Mac App Store release pipeline: `.github/workflows/release-mas.yml` builds,
  signs and uploads to App Store Connect on every push to `main`.
- `ATVRemote/scripts/export-secrets.sh` builds the signing secrets the workflow
  needs and verifies that the generated bundles actually import.
- `ATVRemote/scripts/release.sh` gained `--no-bump` and `--archive-only`, a
  preflight check for both signing identities, and non-interactive App Store
  Connect authentication.

### Fixed
- `release.sh` checked the exit status of `grep` instead of `xcodebuild`, so a
  failed archive could pass as a success.
- `bump-version.sh` used a global `sed` that would rewrite the test targets'
  versions if they ever matched the app's; it now refuses to run when the
  values collide.
- The app target had `CODE_SIGN_STYLE = Manual` without a
  `PROVISIONING_PROFILE_SPECIFIER`, so manual signing had no profile to pick.
- `NSHumanReadableCopyright` was blanked out by an empty build setting and did
  not reach the built app.

### Security
- `.gitignore` had no patterns for certificates or private keys. Added
  `*.p12`, `*.cer`, `*.pem`, `*.key`, `*.csr`, `*.certSigningRequest`,
  `*.mobileprovision`, `*.provisionprofile` and `AuthKey_*.p8`.

## [1.0.9] - 2025-11-17

Last release of the Electron application.

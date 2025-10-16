# Deployment Guide

## Current Setup: Electron App

This is an **Electron-based application**, not a native macOS app. Therefore, **TestFlight is not available** for this project. TestFlight only works with native iOS/macOS apps built with Xcode.

## Deployment Options

### Option 1: Direct Distribution (Recommended)

Use the provided deployment script to build and share the app directly:

```bash
./scripts/deploy-electron.sh
```

**What this does:**
1. Cleans previous builds
2. Installs dependencies
3. Builds the frontend
4. Creates a macOS `.dmg` and `.zip` file
5. Outputs build artifacts in `dist-electron/`

**Sharing with colleagues:**
- Upload the `.dmg` file to:
  - Cloud storage (Dropbox, Google Drive, etc.)
  - Your own server
  - GitHub Releases
  - TestFlight alternatives (see below)

### Option 2: Code Signing & Notarization

For distribution outside of development, you'll need an Apple Developer account ($99/year).

**Setup:**
1. Get an Apple Developer account
2. Create certificates in Xcode
3. Set environment variables:
   ```bash
   export APPLE_ID="your-apple-id@email.com"
   export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
   export APPLE_TEAM_ID="XXXXXXXXXX"
   ```
4. Enable notarization in `electron-builder.yml`:
   ```yaml
   mac:
     notarize: true
   ```
5. Run the deploy script

### Option 3: Mac App Store Distribution

To distribute via Mac App Store (requires native app conversion):
1. Convert to Mac Catalyst or native Swift app
2. Set up Xcode project
3. Configure App Store Connect
4. Use `electron-builder` with `mas` target (limited support)

### Option 4: TestFlight Alternatives for Beta Testing

Since TestFlight isn't available for Electron apps, use these alternatives:

**1. TestFlight Alternative Services:**
- **[Installr](https://www.installrapp.com/)** - Beta distribution for macOS apps
- **[DeployGate](https://deploygate.com/)** - App distribution platform
- **[HockeyApp](https://www.hockeyapp.net/)** (now part of App Center)

**2. GitHub Releases (Free):**
```bash
# Create a release on GitHub
gh release create v1.0.0 dist-electron/*.dmg --title "Version 1.0.0" --notes "Beta release"
```

**3. Auto-Update Server:**
Set up auto-updates using electron-builder's built-in updater:
- Host releases on S3, GitHub, or your server
- Users get automatic updates

## Quick Start

### For Development Testing:
```bash
make run
```

### For Beta Distribution:
```bash
# 1. Build the app
./scripts/deploy-electron.sh

# 2. Share the file in dist-electron/
# Upload ATV Remote-1.0.0.dmg to your preferred service
```

## Environment Variables

For code signing and notarization, the deployment script automatically loads credentials from `.env.deploy`:

### Quick Setup:
```bash
# 1. Copy the example file
cp .env.deploy.example .env.deploy

# 2. Edit with your credentials
nano .env.deploy

# 3. Deploy (automatically loads .env.deploy)
make deploy
```

### `.env.deploy` contents:
```bash
# Apple Developer Account
APPLE_ID=your-apple-id@email.com
APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
APPLE_TEAM_ID=XXXXXXXXXX

# Optional: Code Signing Certificate
CSC_LINK=/path/to/certificate.p12
CSC_KEY_PASSWORD=certificate-password

# Optional: Upload configuration
UPLOAD_TO_S3=false
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
S3_BUCKET=your-bucket-name
```

**Important:**
- `.env.deploy` is in `.gitignore` - your credentials stay private
- The deploy script automatically loads this file if it exists
- See [docs/SIGNING-SETUP.md](docs/SIGNING-SETUP.md) for detailed setup instructions

## Converting to Native macOS App (For TestFlight)

If you want to use TestFlight in the future, you'll need to:

1. **Create a native macOS app** using Swift/SwiftUI
2. **Set up Xcode Cloud** in App Store Connect
3. **Configure Xcode project** with proper schemes and workflows
4. **Use Xcode Cloud CI/CD scripts** instead of shell scripts

This would require a significant refactor of the current Electron architecture.

## Recommended Workflow

For your current use case (sharing with colleague for testing):

1. Run `./scripts/deploy-electron.sh`
2. Upload `dist-electron/ATV Remote-1.0.0.dmg` to cloud storage
3. Share the link with your colleague
4. They download and install it

**Pros:**
- Simple and quick
- No Apple Developer account needed for testing
- Works immediately

**Cons:**
- macOS Gatekeeper may show warning on first launch
- No automatic updates (unless you set up update server)
- Not distributed through official channels

## Next Steps

**For Beta Testing:**
1. Use the deployment script
2. Set up GitHub Releases or a simple file server
3. Share download links with testers

**For Production:**
1. Get Apple Developer account
2. Set up code signing and notarization
3. Consider converting to native app for App Store distribution

## Questions?

- **Q: Can I use TestFlight?**
  A: No, not with Electron. Use alternatives listed above.

- **Q: Do I need to pay $99 for Apple Developer?**
  A: Not for basic testing. Only for code signing and App Store distribution.

- **Q: Can I automate this with CI/CD?**
  A: Yes! Use GitHub Actions or similar. See `CICD.md` for examples.

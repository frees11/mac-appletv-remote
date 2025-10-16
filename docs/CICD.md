# CI/CD Setup Guide

This guide explains how to set up automated builds and deployments for the ATV Remote app.

## GitHub Actions (Recommended)

The project includes a ready-to-use GitHub Actions workflow that automatically builds and releases your app.

### Quick Setup

The workflow file `.github/workflows/deploy.yml` is already configured and ready to use!

**For detailed setup instructions, see: [.github/GITHUB_ACTIONS_SETUP.md](../.github/GITHUB_ACTIONS_SETUP.md)**

### Quick Start

1. **Push a version tag to trigger automatic build:**
   ```bash
   # Use the release script (recommended)
   ./scripts/release.sh

   # Or manually
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Optional: Configure code signing secrets** (for production releases):
   Go to your repository → Settings → Secrets → Actions, and add:

   - `APPLE_ID` - Your Apple ID email
   - `APPLE_APP_SPECIFIC_PASSWORD` - App-specific password from appleid.apple.com
   - `APPLE_TEAM_ID` - Your Apple Developer Team ID
   - `CSC_LINK` - Base64 encoded .p12 certificate
   - `CSC_KEY_PASSWORD` - Certificate password

The workflow automatically:
- Sets up Node.js 20 and Python 3.11
- Installs all dependencies with caching
- Builds Python backend with PyInstaller
- Generates app icons with ImageMagick
- Builds frontend with Vite
- Creates macOS DMG and ZIP installers (x64 + arm64)
- Uploads build artifacts
- **Creates GitHub Release with DMG files attached**

### Manual Trigger

You can also trigger builds manually without creating a tag:
1. Go to Actions tab in GitHub
2. Select "Build and Release" workflow
3. Click "Run workflow"
4. Choose your branch (usually `main`)

This is useful for testing the workflow.

## Alternative CI/CD Platforms

### GitLab CI

Create `.gitlab-ci.yml`:

```yaml
image: node:18

stages:
  - build
  - deploy

build-macos:
  stage: build
  script:
    - npm ci
    - npm run build
    - npm run electron:build -- --mac
  artifacts:
    paths:
      - dist-electron/
  only:
    - tags

deploy:
  stage: deploy
  script:
    - echo "Deploy to your server"
  only:
    - tags
```

### CircleCI

Create `.circleci/config.yml`:

```yaml
version: 2.1

jobs:
  build:
    macos:
      xcode: "14.2.0"
    steps:
      - checkout
      - run: npm ci
      - run: npm run build
      - run: npm run electron:build -- --mac
      - store_artifacts:
          path: dist-electron

workflows:
  build-deploy:
    jobs:
      - build:
          filters:
            tags:
              only: /^v.*/
```

## Local Deployment

For manual deployments from your machine:

```bash
# Load environment variables
source .env.deploy

# Run deployment
make deploy

# Or directly
./scripts/deploy-electron.sh
```

## Code Signing Setup

### Prerequisites

1. **Apple Developer Account** ($99/year)
2. **Developer ID Certificate** from Apple Developer portal
3. **App-specific password** from appleid.apple.com

### Step-by-Step

1. **Create certificates in Xcode:**
   - Open Xcode
   - Preferences → Accounts
   - Add your Apple ID
   - Manage Certificates → Create "Developer ID Application"

2. **Export certificate:**
   - Open Keychain Access
   - Find your "Developer ID Application" certificate
   - Right-click → Export
   - Save as `.p12` file with password

3. **Set up environment variables:**
   ```bash
   cp .env.deploy.example .env.deploy
   # Edit .env.deploy with your credentials
   source .env.deploy
   ```

4. **Enable notarization:**
   In `electron-builder.yml`:
   ```yaml
   mac:
     notarize: true
   ```

5. **Build with signing:**
   ```bash
   make deploy
   ```

## Auto-Update Setup

Enable automatic updates for your distributed app:

### 1. Set up update server

**Option A: GitHub Releases (Free)**
```yaml
# In electron-builder.yml
publish:
  provider: github
  owner: your-username
  repo: atv-remote
```

**Option B: Custom Server**
```yaml
# In electron-builder.yml
publish:
  provider: generic
  url: https://your-server.com/releases
```

### 2. Add update code to app

In `electron/main.js`:
```javascript
const { autoUpdater } = require('electron-updater');

app.on('ready', () => {
  // Check for updates
  autoUpdater.checkForUpdatesAndNotify();
});

autoUpdater.on('update-available', () => {
  console.log('Update available!');
});

autoUpdater.on('update-downloaded', () => {
  console.log('Update downloaded; will install on restart');
});
```

### 3. Create release with GitHub Actions

The workflow automatically creates releases when you push tags.

## Distribution Strategies

### For Beta Testers

1. **GitHub Releases (Recommended)**
   - Automatic with CI/CD
   - Version history
   - Easy download links
   - Free

2. **Cloud Storage**
   - Upload DMG to Dropbox/Google Drive
   - Share link with testers
   - Simple but manual

3. **Beta Distribution Services**
   - [Installr](https://www.installrapp.com/)
   - [DeployGate](https://deploygate.com/)
   - TestFlight alternatives

### For Production

1. **Direct Download**
   - Host on your website
   - Use auto-updater for updates

2. **Mac App Store**
   - Requires Mac App Store certificate
   - Different entitlements
   - Apple review process

## Troubleshooting

### Build fails on CI

**Problem:** Missing dependencies
```bash
# Solution: Add to workflow
- run: npm ci --legacy-peer-deps
```

**Problem:** Code signing fails
```bash
# Solution: Check secrets are set correctly
# Verify CSC_LINK is base64 encoded
```

### Notarization fails

**Problem:** Invalid credentials
```bash
# Check Apple ID and app-specific password
# Verify team ID is correct
```

**Problem:** Entitlements issues
```bash
# Check build/entitlements.mac.plist
# Ensure hardened runtime is enabled
```

### Users can't open app

**Problem:** "App is damaged and can't be opened"
```bash
# Solution: Enable code signing and notarization
# Or have users right-click → Open
```

## Best Practices

1. **Version numbering:** Use semantic versioning (1.0.0, 1.1.0, 2.0.0)
2. **Changelog:** Maintain CHANGELOG.md for release notes
3. **Testing:** Test builds locally before pushing tags
4. **Backups:** Keep old releases available for rollback
5. **Monitoring:** Track download counts and crash reports

## Next Steps

- [ ] Set up GitHub Actions workflow
- [ ] Configure code signing
- [ ] Test deployment process
- [ ] Set up auto-updates
- [ ] Document release process for team

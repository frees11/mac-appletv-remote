# GitHub Actions Auto-Deploy Setup

This document explains how to configure automatic builds and releases for ATV Remote using GitHub Actions.

## Overview

The GitHub Actions workflow automatically:
1. Builds the Python backend with PyInstaller
2. Generates app icons
3. Builds the Electron frontend
4. Creates macOS DMG and ZIP installers
5. Uploads builds to GitHub Releases

## How It Works

### Trigger Methods

The workflow triggers on:
- **Version tags**: Push a tag like `v1.0.0` to create a release
- **Manual trigger**: Run from GitHub Actions tab using "workflow_dispatch"

### Build Process

```
Tag Push (v1.0.0)
    ↓
GitHub Actions Starts
    ↓
Setup Environment (Node.js, Python, ImageMagick)
    ↓
Install Dependencies
    ↓
Build Python Backend → PyInstaller bundle
    ↓
Generate Icons → ImageMagick conversion
    ↓
Build Frontend → Vite production build
    ↓
Build Electron App → electron-builder (x64 + arm64)
    ↓
Create GitHub Release → Upload DMG + ZIP files
```

## Quick Start

### 1. Enable GitHub Actions

1. Push the `.github/workflows/deploy.yml` file to your repository
2. Go to your repository on GitHub
3. Click the "Actions" tab
4. Workflows should be automatically enabled

### 2. Create a Release

Using the release script:

```bash
./scripts/release.sh
```

This script will:
1. Ask for new version number
2. Update package.json
3. Create git commit and tag
4. Push to GitHub (triggers workflow)

**Manual method:**

```bash
# Update version in package.json
npm version 1.0.0 --no-git-tag-version

# Commit and tag
git add package.json package-lock.json
git commit -m "chore: bump version to 1.0.0"
git tag -a v1.0.0 -m "Release v1.0.0"

# Push (triggers GitHub Actions)
git push origin main
git push origin v1.0.0
```

### 3. Monitor Build

1. Go to **Actions** tab on GitHub
2. Click on the running workflow
3. Watch the build progress
4. Build takes ~10-15 minutes

### 4. Download Release

Once complete:
1. Go to **Releases** section
2. Find your version (e.g., v1.0.0)
3. Download DMG or ZIP files

## Code Signing (Optional)

For distributing to users outside your organization, you need Apple Developer code signing.

### Required Certificates

1. **Apple Developer Account** ($99/year)
2. **Developer ID Application Certificate**
3. **App-Specific Password** for notarization

### Setup GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `APPLE_ID` | Your Apple ID email | developer.apple.com account |
| `APPLE_APP_SPECIFIC_PASSWORD` | App password for notarization | appleid.apple.com → App-Specific Passwords |
| `APPLE_TEAM_ID` | Your team ID | developer.apple.com → Membership |
| `CSC_LINK` | Base64-encoded .p12 certificate | Export from Keychain Access |
| `CSC_KEY_PASSWORD` | Certificate password | Password set during export |

### Creating CSC_LINK

1. Open **Keychain Access**
2. Find your "Developer ID Application" certificate
3. Right-click → **Export**
4. Save as `.p12` with a password
5. Convert to base64:

```bash
base64 -i certificate.p12 | pbcopy
```

6. Paste into `CSC_LINK` secret

### Without Code Signing

The workflow works without code signing, but users will see:
- "App from unidentified developer" warning
- Must right-click → Open to bypass Gatekeeper

## Workflow Configuration

### File Location
```
.github/workflows/deploy.yml
```

### Key Features

- **Node.js 20**: Latest LTS version
- **Python 3.11**: Compatible with PyInstaller
- **Caching**: npm and pip caches for faster builds
- **Multi-arch**: Builds for Intel (x64) and Apple Silicon (arm64)
- **Artifact upload**: 7-day retention for build files
- **Auto-release notes**: GitHub generates changelog from commits

### Customization

Edit `.github/workflows/deploy.yml`:

```yaml
# Change Node.js version
node-version: '20'  # or '18', '21', etc.

# Change Python version
python-version: '3.11'  # or '3.10', '3.12', etc.

# Change artifact retention
retention-days: 7  # number of days to keep artifacts

# Add Slack notifications
- name: Notify Slack
  if: success()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
      -H 'Content-Type: application/json' \
      -d '{"text":"Release ${{ github.ref_name }} deployed!"}'
```

## Troubleshooting

### Build fails at "Build Python backend"

**Issue**: PyInstaller fails or missing dependencies

**Solution**:
```bash
# Test locally first
./scripts/build-backend.sh

# Check requirements.txt has all dependencies
cd backend
pip install -r requirements.txt
```

### Build fails at "Generate app icons"

**Issue**: ImageMagick not found or SVG invalid

**Solution**:
```bash
# Test locally
brew install imagemagick
./scripts/generate-icons.sh

# Check SVG file exists
ls -la "atv remote v2.1.svg"
```

### DMG not created

**Issue**: electron-builder fails

**Solution**:
```bash
# Test build locally
npm run electron:build

# Check electron-builder.yml is valid
# Check all files in 'files' section exist
```

### Code signing fails

**Issue**: Invalid certificate or missing secrets

**Solution**:
1. Verify secrets are set correctly in GitHub
2. Test certificate locally:
```bash
security find-identity -v -p codesigning
```
3. Check certificate expiration date

### Release not created

**Issue**: Tag format incorrect or permissions missing

**Solution**:
- Use format: `v1.0.0` (must start with 'v')
- Check repository permissions (Settings → Actions → General)
- Enable "Read and write permissions" for GITHUB_TOKEN

## Local Testing

Before pushing a tag, test the build locally:

```bash
# Clean build
rm -rf dist dist-electron node_modules backend/venv

# Fresh install
npm ci

# Full build
./scripts/deploy-electron.sh
```

If local build succeeds, GitHub Actions should work.

## Manual Workflow Trigger

Test without creating a tag:

1. Go to **Actions** tab
2. Select "Build and Release" workflow
3. Click **Run workflow**
4. Choose branch (usually `main`)
5. Click **Run workflow** button

This builds without creating a release.

## Best Practices

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- `v1.0.0`: Major release (breaking changes)
- `v1.1.0`: Minor release (new features)
- `v1.0.1`: Patch release (bug fixes)

### Release Checklist

Before creating a release:

- [ ] Update version in package.json
- [ ] Test build locally (`./scripts/deploy-electron.sh`)
- [ ] Update CHANGELOG or release notes
- [ ] Commit all changes
- [ ] Create and push tag
- [ ] Monitor GitHub Actions build
- [ ] Test downloaded release
- [ ] Announce to users

## Support

For issues:
1. Check workflow logs in Actions tab
2. Review this documentation
3. Test build locally
4. Open issue with error logs

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [electron-builder Documentation](https://www.electron.build/)
- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [PyInstaller Documentation](https://pyinstaller.org/)

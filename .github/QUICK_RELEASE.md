# Quick Release Guide

## Automatic Releases (Default)

**Verzia sa automaticky zvyšuje pri každom push do main!**

### Just push your code:

```bash
git add .
git commit -m "feat: tvoja zmena"
git push origin main
```

**Hotovo!** GitHub Actions automaticky:
1. Zvýši verziu (1.0.0 → 1.0.1)
2. Zbuildí aplikáciu (~10-15 minút)
3. Vytvorí release v **Releases** s DMG súbormi

### Monitor the Build:

1. GitHub → **Actions** tab
2. Watch the "Build and Release" workflow
3. When done: **Releases** → Download DMG

**See details:** [AUTO_RELEASE.md](AUTO_RELEASE.md)

---

## Manual Release (Alternative)

Ak chceš vlastnú verziu alebo release notes:

### 1. Run the Release Script

```bash
./scripts/release.sh
```

This script will:
- Ask you for the new version number (e.g., `1.2.0`)
- Update `package.json`
- Create a git commit
- Create a git tag (e.g., `v1.2.0`)
- Push to GitHub

### 2. Monitor the Build

1. Go to your repository on GitHub
2. Click the **Actions** tab
3. Watch the "Build and Release" workflow run
4. Build takes about 10-15 minutes

### 3. Download Your Release

Once the workflow completes:

1. Go to **Releases** section on GitHub
2. Find your version (e.g., `v1.2.0`)
3. Download the DMG files:
   - `ATV-Remote-1.2.0-arm64.dmg` - For Apple Silicon Macs (M1/M2/M3)
   - `ATV-Remote-1.2.0-x64.dmg` - For Intel Macs
   - `ATV-Remote-1.2.0-arm64-mac.zip` - ZIP version (arm64)
   - `ATV-Remote-1.2.0-x64-mac.zip` - ZIP version (x64)

---

## Which Method to Use?

| Use Case | Method |
|----------|--------|
| **Daily development** | Automatic (just push) |
| **Bug fixes** | Automatic (just push) |
| **Minor features** | Automatic (just push) |
| **Major release** | Manual (`npm version major && git push`) |
| **Custom version** | Manual (`./scripts/release.sh`) |
| **Special release notes** | Manual (edit release after auto-build) |

---

## Manual Method (Alternative)

If you prefer to do it manually:

```bash
# 1. Update version
npm version 1.0.1 --no-git-tag-version

# 2. Commit
git add package.json package-lock.json
git commit -m "chore: bump version to 1.0.1"

# 3. Tag
git tag -a v1.0.1 -m "Release v1.0.1"

# 4. Push (triggers GitHub Actions)
git push origin main
git push origin v1.0.1
```

---

## First Time Setup

### No Code Signing (Testing/Beta)

No setup needed! The workflow works out of the box.

Users will see a warning when opening the app:
- Right-click → Open to bypass Gatekeeper

### With Code Signing (Production)

For production releases without warnings, add these GitHub Secrets:

**Settings → Secrets and variables → Actions → New repository secret**

1. `APPLE_ID` - Your Apple ID email
2. `APPLE_APP_SPECIFIC_PASSWORD` - From appleid.apple.com
3. `APPLE_TEAM_ID` - From developer.apple.com
4. `CSC_LINK` - Base64 certificate (see below)
5. `CSC_KEY_PASSWORD` - Certificate password

**Creating CSC_LINK:**

```bash
# Export certificate from Keychain Access
# Save as certificate.p12 with a password

# Convert to base64
base64 -i certificate.p12 | pbcopy

# Paste into CSC_LINK secret
```

See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for detailed instructions.

---

## Troubleshooting

### Build Failed?

1. Check the Actions tab for error logs
2. Common issues:
   - Python backend build failed → Test locally: `./scripts/build-backend.sh`
   - Icon generation failed → Install ImageMagick: `brew install imagemagick`
   - Electron build failed → Test locally: `npm run electron:build`

### No Release Created?

- Make sure you pushed a tag starting with `v` (e.g., `v1.0.0`)
- Check repository permissions: Settings → Actions → General → Workflow permissions → "Read and write permissions"

### Want to Test Without Creating a Release?

1. Go to Actions tab
2. Select "Build and Release" workflow
3. Click "Run workflow"
4. This builds without creating a release

---

## Version Numbering

Use [Semantic Versioning](https://semver.org/):

- `v1.0.0` → First release
- `v1.0.1` → Bug fixes only
- `v1.1.0` → New features (backwards compatible)
- `v2.0.0` → Breaking changes

---

## Need Help?

- **Full documentation**: [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)
- **CI/CD guide**: [../docs/CICD.md](../docs/CICD.md)
- **Deployment guide**: [../DEPLOYMENT.md](../DEPLOYMENT.md)

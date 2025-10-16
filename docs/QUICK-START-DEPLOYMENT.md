# Quick Start: Deploy to Beta Testers

**Goal:** Share your ATV Remote app with a colleague for testing.

## ⚡ Fastest Method (5 minutes)

### 1. Build the app
```bash
make deploy
```

This creates a `.dmg` file in `dist-electron/` directory.

### 2. Share the file

**Option A: Cloud Storage (Easiest)**
```bash
# Upload to your cloud storage and share the link
# Examples:
# - Dropbox
# - Google Drive
# - iCloud Drive
```

**Option B: GitHub Releases (Recommended)**
```bash
# Create a release
./scripts/release.sh

# Or manually
git tag v1.0.0
git push origin v1.0.0
```

If you have GitHub Actions set up, this automatically builds and creates a release.

### 3. Colleague installs

They download the `.dmg` file:
1. Double-click to mount
2. Drag app to Applications
3. Right-click → Open (first time only, due to macOS Gatekeeper)

## 🎯 Recommended: GitHub Releases (10 minutes setup)

### One-time setup:

1. **Enable GitHub Actions:**
   ```bash
   cp .github/workflows/deploy.yml.example .github/workflows/deploy.yml
   git add .github/workflows/deploy.yml
   git commit -m "feat: add GitHub Actions deployment"
   git push
   ```

2. **Create first release:**
   ```bash
   ./scripts/release.sh
   # Enter version: 1.0.0
   # Press y to confirm
   ```

3. **Share release link:**
   - Go to your GitHub repository → Releases
   - Copy link to latest release
   - Share with colleague

### Future releases:
```bash
./scripts/release.sh
# That's it! CI/CD handles everything
```

## 🔒 Optional: Code Signing (Skip for testing)

For beta testing with colleagues, you **don't need** code signing. Users just need to right-click → Open on first launch.

**Only set up code signing if:**
- Distributing to many users
- Want to remove Gatekeeper warnings
- Publishing to Mac App Store

See [DEPLOYMENT.md](DEPLOYMENT.md) for code signing setup.

## 📋 Quick Reference

| Method | Setup Time | Best For | Cost |
|--------|-----------|----------|------|
| `make deploy` + Share DMG | 2 min | Quick testing | Free |
| GitHub Releases | 10 min | Regular updates | Free |
| Code Signing | 1 hour | Wide distribution | $99/year |
| Mac App Store | Several days | Public release | $99/year |

## ❓ Troubleshooting

### "App is damaged and can't be opened"
**Solution:** Tell user to right-click → Open (instead of double-clicking)

### "Build failed"
**Solution:**
```bash
make clean
npm install
make deploy
```

### "Script permission denied"
**Solution:**
```bash
chmod +x scripts/deploy-electron.sh
chmod +x scripts/release.sh
```

## 🎉 Success!

Your colleague should now be able to:
1. Download the app
2. Install it
3. Test all features
4. Report bugs

## Next Steps

- [ ] Build and share first version
- [ ] Get feedback from colleague
- [ ] Fix bugs
- [ ] Create new release
- [ ] Set up auto-updates (optional)

For more details, see:
- [DEPLOYMENT.md](DEPLOYMENT.md) - Full deployment guide
- [CICD.md](CICD.md) - Automated deployment setup

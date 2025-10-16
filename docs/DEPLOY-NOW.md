# Deploy with Code Signing & Notarization - Step by Step

Your credentials are set up! Here's exactly what to do now. 🚀

## ✅ What's Already Done:

1. ✅ `.env.deploy` file is configured
2. ✅ Notarization is enabled in `electron-builder.yml`
3. ✅ Icons are generated
4. ✅ Your Apple Developer credentials:
   - Apple ID: `apps@launchette.co`
   - Team ID: `YK34UDN964`
   - App-Specific Password: Set ✅

## 🔑 Step 1: Get Your Code Signing Certificate

You need a "Developer ID Application" certificate. Here's how to get it:

### Option A: Let Xcode Create It (Easiest - 2 minutes)

**1. Open Xcode** (if you don't have it, download from Mac App Store)

**2. Go to:** Xcode → Settings (or Preferences)

**3. Click:** "Accounts" tab

**4. Sign in:**
- Click the "+" button at bottom left
- Select "Apple ID"
- Enter: `apps@launchette.co`
- Enter your password

**5. Download certificates:**
- Select your account in the list
- Click "Manage Certificates..." button
- Click the "+" button at bottom left
- Select **"Developer ID Application"**
- Click "Done"

**6. Done!** ✅ The certificate is now installed.

### Option B: Electron Builder Downloads It Automatically

If you don't want to use Xcode, electron-builder will try to download the certificate automatically using your credentials. Just proceed to Step 2!

## 🚀 Step 2: Deploy Your App

Now run this single command:

```bash
make deploy
```

## 📊 What Will Happen:

You'll see these steps:

```
🚀 Starting ATV Remote Electron build and deployment...
📄 Loading environment variables from .env.deploy  ← Your credentials loaded!
📥 Installing dependencies...
🎨 Generating icons...
🏗️  Building frontend...
⚡ Building Electron app for macOS...
  • signing         ← Code signing with your certificate
  • notarizing      ← Sending to Apple for notarization
  • notarized       ← Apple approved it!
  • building dmg    ← Creating the .dmg file
✅ Build complete!
```

**Note:** Notarization can take 1-10 minutes. Apple needs to scan your app.

## ⏱️ Timeline:

- **Code signing:** ~30 seconds
- **Building DMG:** ~1 minute
- **Notarization:** 1-10 minutes (Apple's servers)
- **Total:** ~5-15 minutes for first build

## ✅ Success Looks Like:

When done, you'll see:

```
✅ Build complete!

📦 Build artifacts:
-rw-r--r--  ATV Remote-1.0.0.dmg  (123 MB)
-rw-r--r--  ATV Remote-1.0.0-mac.zip  (118 MB)
```

## 🎉 Your App Is Now:

- ✅ **Code signed** - Has your Developer ID
- ✅ **Notarized** - Approved by Apple
- ✅ **Ready to share** - No warnings for users!

## 📤 Step 3: Share with Your Colleague

```bash
# Open the folder
open dist-electron/

# Upload the .dmg file to:
# - Dropbox
# - Google Drive
# - Your server
# - Email (if small enough)
```

**Users can:**
- Double-click to install
- No "unidentified developer" warning!
- No need to right-click → Open

## ⚠️ Troubleshooting

### "No identity found for signing"

**Solution:** Create certificate in Xcode (Option A above) or run:
```bash
# electron-builder will try to download it
make deploy
```

### "Authentication failed"

**Check:**
- Apple ID is correct: `apps@launchette.co`
- App-specific password is correct (not your regular password)
- Team ID is correct: `YK34UDN964`
- Your Apple Developer membership is active ($99/year)

**Fix:**
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Generate a NEW app-specific password
3. Update `.env.deploy` with the new password
4. Try again: `make deploy`

### "Notarization timeout"

**This is normal!** Apple's servers can be slow. Just wait. You'll see:
```
• notarizing       file=dist-electron/ATV Remote-1.0.0.dmg
```

If it takes more than 15 minutes:
- Check [developer.apple.com](https://developer.apple.com) status page
- Try again later
- The build already succeeded - notarization is the last step

### "Invalid entitlements"

**Solution:** The entitlements file is already correct. But if you see this:
```bash
# Check the file exists
ls -la build/entitlements.mac.plist

# If missing, the build process should create it
npm run icons
```

## 🔍 Check Your Certificate Status

Run this to see if your certificate is installed:

```bash
security find-identity -v -p codesigning
```

You should see something like:
```
1) ABC123... "Developer ID Application: Your Name (YK34UDN964)"
```

If you see nothing, follow "Step 1: Get Your Code Signing Certificate" above.

## 📱 For Next Deploys:

Once everything is set up, future deployments are simple:

```bash
make deploy
```

That's it! Your credentials are saved in `.env.deploy` and will be used automatically.

## 🎯 Quick Commands:

```bash
# Deploy (sign + notarize)
make deploy

# Check certificates
security find-identity -v -p codesigning

# Clean and rebuild
make clean && make deploy

# Test without building
security find-identity -v
```

## 📚 Need More Help?

- **Certificate issues:** [docs/SIGNING-SETUP.md](SIGNING-SETUP.md)
- **Full guide:** [../DEPLOYMENT.md](../DEPLOYMENT.md)
- **CI/CD setup:** [CICD.md](CICD.md)

---

Ready? Let's deploy! 🚀

```bash
make deploy
```

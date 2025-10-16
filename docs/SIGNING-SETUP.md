# Code Signing Setup Guide

This guide helps you set up Apple code signing and notarization for your Electron app.

## Quick Setup

### 1. Create `.env.deploy` file

```bash
cp .env.deploy.example .env.deploy
```

### 2. Edit `.env.deploy` with your credentials

```bash
# Use your favorite editor
nano .env.deploy
# or
code .env.deploy
```

### 3. Fill in your Apple Developer credentials

```bash
# Apple Developer Account
APPLE_ID=your-apple-id@email.com
APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
APPLE_TEAM_ID=XXXXXXXXXX

# Optional: Code Signing Certificate
CSC_LINK=/path/to/certificate.p12
CSC_KEY_PASSWORD=certificate-password

# Optional: Upload to cloud
UPLOAD_TO_S3=false
```

### 4. Deploy with automatic signing

```bash
make deploy
```

That's it! The deployment script will automatically load your credentials from `.env.deploy`.

## Getting Your Credentials

### Apple ID
Your Apple Developer account email address.
- Example: `john@example.com`
- Get it from: [developer.apple.com](https://developer.apple.com)

### App-Specific Password
A special password for command-line tools (not your regular Apple ID password).

**How to generate:**
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Go to "Security" section
4. Under "App-Specific Passwords", click "Generate Password"
5. Give it a label (e.g., "Electron Builder")
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

### Team ID
Your Apple Developer Team ID.

**How to find it:**
1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Click on "Membership" in the sidebar
3. Your Team ID is shown (10 characters, e.g., `A1B2C3D4E5`)

Or in Xcode:
1. Open Xcode
2. Preferences → Accounts
3. Select your Apple ID
4. Your Team ID is shown next to your team name

### Code Signing Certificate (Optional)

**If you have a certificate:**
1. Open Keychain Access
2. Find "Developer ID Application" certificate
3. Right-click → Export "Developer ID Application"
4. Save as `.p12` file with a password
5. Put the path in `.env.deploy`:
   ```bash
   CSC_LINK=/Users/yourname/Certificates/developer-id.p12
   CSC_KEY_PASSWORD=your-certificate-password
   ```

**If you don't have a certificate:**
- Leave `CSC_LINK` and `CSC_KEY_PASSWORD` commented out
- electron-builder will try to find certificates automatically
- Or create one in Xcode (Preferences → Accounts → Manage Certificates)

## Security Best Practices

### ✅ DO:
- Keep `.env.deploy` local only (it's in `.gitignore`)
- Use app-specific passwords (never your main Apple ID password)
- Rotate app-specific passwords periodically
- Use different passwords for different tools

### ❌ DON'T:
- Commit `.env.deploy` to git
- Share your `.env.deploy` file
- Use your main Apple ID password
- Hardcode credentials in scripts

## File Structure

```
your-project/
├── .env.deploy.example    # Template (committed to git)
├── .env.deploy             # Your credentials (NOT committed)
└── scripts/
    └── deploy-electron.sh  # Automatically loads .env.deploy
```

## Testing Your Setup

### Test without building:
```bash
# Load your environment
source .env.deploy

# Check variables are set
echo $APPLE_ID
echo $APPLE_TEAM_ID
# Don't echo the password for security!
```

### Test with building:
```bash
make deploy
```

If credentials are loaded correctly, you'll see:
```
📄 Loading environment variables from .env.deploy
```

## Troubleshooting

### "No .env.deploy file found"
- You need to create it: `cp .env.deploy.example .env.deploy`
- Make sure it's in the project root directory

### "Code signing failed"
- Check your Apple ID and password are correct
- Ensure you have a valid Developer ID certificate
- Try signing in to [developer.apple.com](https://developer.apple.com) to verify account status
- Check your Apple Developer Program membership is active

### "Notarization failed"
- Verify your app-specific password is correct
- Check your Team ID matches your account
- Ensure you have the necessary entitlements
- Review Apple's notarization logs

### "Certificate not found"
- Open Xcode and check Preferences → Accounts → Manage Certificates
- Create a "Developer ID Application" certificate if missing
- Or remove `CSC_LINK` from `.env.deploy` to let electron-builder find it automatically

## Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `APPLE_ID` | For notarization | Apple Developer email | `john@example.com` |
| `APPLE_APP_SPECIFIC_PASSWORD` | For notarization | App-specific password | `xxxx-xxxx-xxxx-xxxx` |
| `APPLE_TEAM_ID` | For notarization | 10-character Team ID | `A1B2C3D4E5` |
| `CSC_LINK` | Optional | Path to .p12 certificate | `/path/to/cert.p12` |
| `CSC_KEY_PASSWORD` | If using CSC_LINK | Certificate password | `your-password` |
| `NOTARIZE` | Optional | Enable/disable notarization | `true` or `false` |
| `UPLOAD_TO_S3` | Optional | Upload to S3 after build | `true` or `false` |

## Without Code Signing

You can still build and distribute without code signing:
1. Don't create `.env.deploy`
2. Run `make deploy`
3. Share the `.dmg` file
4. Users will see "unidentified developer" warning
5. Users must right-click → Open to bypass Gatekeeper

This is fine for:
- Internal testing
- Beta distribution to colleagues
- Development builds

For wider distribution, code signing is recommended.

## Next Steps

1. **For testing**: Skip code signing, just run `make deploy`
2. **For beta users**: Set up basic code signing (no notarization)
3. **For public release**: Set up full code signing + notarization
4. **For App Store**: Different process, see Apple's documentation

## Resources

- [Apple Developer Portal](https://developer.apple.com/account)
- [App-Specific Passwords](https://appleid.apple.com)
- [electron-builder Code Signing](https://www.electron.build/code-signing)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

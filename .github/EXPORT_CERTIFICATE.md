# How to Export Certificate from Keychain for GitHub Actions

## Step-by-Step Guide

### 1. Open Keychain Access
```bash
# Open via Spotlight
Cmd + Space → type "Keychain Access" → Enter

# Or via Terminal
open -a "Keychain Access"
```

### 2. Find Your Certificate

1. In the left sidebar, select **"login"** keychain
2. In the category list (left bottom), select **"My Certificates"**
3. Look for one of these:
   - **"Developer ID Application: ..."**
   - **"Apple Development: ..."**
   - **"Apple Distribution: ..."**

**IMPORTANT:** You need the certificate WITH the private key (it should have a small key icon ▸ next to it)

### 3. Export Certificate (Correct Way)

#### Method 1: Export Certificate + Private Key together (RECOMMENDED)

1. Click on the **triangle (▸)** next to your certificate to expand it
2. You should see the certificate AND the private key underneath
3. **Right-click on the CERTIFICATE** (not the private key)
4. Select **"Export '...' "**
5. In the dialog:
   - **File Format:** Select **"Personal Information Exchange (.p12)"**
   - **Where:** Desktop
   - **Name:** `developer_id.p12`
6. Click **"Save"**
7. Enter a password (e.g., `mypassword123`) → Click **"OK"**
8. Enter your Mac login password to allow export

#### Method 2: If .p12 is not available

If you can't select .p12:

**The certificate might not have the private key associated!**

Try this:
1. Look for the certificate in **"Certificates"** category (not "My Certificates")
2. Check if there's a key icon ▸ - if not, you need to:
   - Re-download the certificate from Apple Developer portal
   - OR generate a new certificate

### 4. Convert to Base64

```bash
# Navigate to where you saved the .p12
cd ~/Desktop

# Convert to base64 and copy to clipboard
base64 -i developer_id.p12 | pbcopy

# Or save to file
base64 -i developer_id.p12 -o developer_id.txt
```

### 5. Add to GitHub Secrets

1. Go to: https://github.com/frees11/mac-appletv-remote/settings/secrets/actions
2. Click **"New repository secret"**
3. **Name:** `CSC_LINK`
4. **Secret:** Paste the base64 string (Cmd+V)
5. Click **"Add secret"**

6. Create another secret:
   - **Name:** `CSC_KEY_PASSWORD`
   - **Secret:** The password you used in step 3 (e.g., `mypassword123`)

### 6. Verify Certificate in Keychain

To check if you have the right certificate:

```bash
# List all code signing identities
security find-identity -v -p codesigning

# You should see something like:
# 1) ABC123... "Developer ID Application: Your Name (TEAM_ID)"
```

## Troubleshooting

### Problem: Cannot export as .p12

**Cause:** The certificate doesn't have a private key associated

**Solution:**
1. Check if the certificate has a ▸ icon that expands to show a private key
2. If not, you need to:
   - Delete the certificate
   - Download it again from developer.apple.com
   - Make sure to import BOTH the certificate AND the private key

### Problem: "This certificate has an invalid issuer"

**Cause:** Missing intermediate certificates

**Solution:**
```bash
# Download Apple intermediate certificates
# They should already be in your keychain if you can sign locally
```

### Problem: exported .p12 file is very small (<1KB)

**Cause:** Export didn't include private key

**Solution:**
- Make sure to expand the certificate (click ▸)
- Right-click on the certificate NAME, not the key
- Try exporting from "login" keychain, not "System"

## Alternative: Create New Certificate

If you can't export the existing one:

1. Go to https://developer.apple.com/account/resources/certificates
2. Create new **"Developer ID Application"** certificate
3. Download the .cer file
4. Double-click to import into Keychain
5. Now it should have the private key and you can export as .p12

## Security Note

⚠️ **IMPORTANT:** The .p12 file contains your private key!

- Don't share it publicly
- Delete it after uploading to GitHub Secrets
- GitHub Secrets are encrypted and secure
- Only GitHub Actions will have access to it

```bash
# After uploading to GitHub, delete local files:
rm ~/Desktop/developer_id.p12
rm ~/Desktop/developer_id.txt  # if you created this
```

# Export Certificate via Terminal (Easier Method)

Since you already have the certificate with private key in your keychain, you can export it directly via Terminal:

## Method 1: Export via Terminal (RECOMMENDED)

```bash
# Set password for the .p12 file
P12_PASSWORD="your-secure-password-here"

# Export certificate + private key to .p12
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -P "$P12_PASSWORD" \
  -o ~/Desktop/developer_id.p12 \
  "Developer ID Application: Aurodent CZ, s.r.o."

# Convert to base64
base64 -i ~/Desktop/developer_id.p12 | pbcopy

echo "✅ Base64 copied to clipboard!"
echo "Now add it to GitHub Secrets:"
echo "  Name: CSC_LINK"
echo "  Value: (paste from clipboard)"
echo ""
echo "And add another secret:"
echo "  Name: CSC_KEY_PASSWORD"
echo "  Value: $P12_PASSWORD"
```

## Method 2: If Method 1 Asks for Password

You'll be prompted for your Mac login password. Enter it and the export will complete.

If it fails, try specifying the identity by hash:

```bash
# Your certificate hash
CERT_HASH="B189E89A9BC71C14E0C72C107C5209D540AB5336"
P12_PASSWORD="your-secure-password-here"

# Export by hash
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -P "$P12_PASSWORD" \
  -o ~/Desktop/developer_id.p12 \
  "$CERT_HASH"

# Convert to base64
base64 -i ~/Desktop/developer_id.p12 | pbcopy

echo "✅ Done! Base64 is in clipboard"
```

## Why Keychain Access GUI Doesn't Show It

The certificate IS there with private key, but Keychain Access GUI sometimes doesn't display the private key separately. The terminal method works because it accesses the keychain directly.

## Full Automated Script

Create a file `export-cert.sh`:

```bash
#!/bin/bash

# Configuration
CERT_NAME="Developer ID Application: Aurodent CZ, s.r.o."
OUTPUT_FILE="$HOME/Desktop/developer_id.p12"
P12_PASSWORD="MySecurePassword123"

echo "🔐 Exporting certificate from keychain..."

# Export certificate + private key
security export -k "$HOME/Library/Keychains/login.keychain-db" \
  -t identities \
  -f pkcs12 \
  -P "$P12_PASSWORD" \
  -o "$OUTPUT_FILE" \
  "$CERT_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Certificate exported successfully!"
    echo "📁 Location: $OUTPUT_FILE"
    echo ""

    # Convert to base64
    echo "🔄 Converting to base64..."
    BASE64_CERT=$(base64 -i "$OUTPUT_FILE")
    echo "$BASE64_CERT" | pbcopy

    echo "✅ Base64 copied to clipboard!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Go to: https://github.com/frees11/mac-appletv-remote/settings/secrets/actions"
    echo "2. Create secret 'CSC_LINK' and paste the base64 (Cmd+V)"
    echo "3. Create secret 'CSC_KEY_PASSWORD' with value: $P12_PASSWORD"
    echo ""
    echo "🗑️  Don't forget to delete the .p12 file after uploading:"
    echo "   rm $OUTPUT_FILE"
else
    echo "❌ Export failed!"
    echo "You may need to enter your Mac login password"
fi
```

Make it executable and run:

```bash
chmod +x export-cert.sh
./export-cert.sh
```

## Verify the Export

Check if the .p12 file was created correctly:

```bash
# Check file size (should be several KB, not empty)
ls -lh ~/Desktop/developer_id.p12

# Verify the certificate in the .p12
openssl pkcs12 -in ~/Desktop/developer_id.p12 -nokeys -info
# Enter the password you used during export
```

## Add to GitHub Secrets

1. **CSC_LINK**:
   - Go to https://github.com/frees11/mac-appletv-remote/settings/secrets/actions
   - New repository secret
   - Name: `CSC_LINK`
   - Value: (paste the base64 from clipboard)

2. **CSC_KEY_PASSWORD**:
   - New repository secret
   - Name: `CSC_KEY_PASSWORD`
   - Value: (the password you used, e.g., `MySecurePassword123`)

3. **Clean up**:
   ```bash
   rm ~/Desktop/developer_id.p12
   ```

## Troubleshooting

### "User interaction is not allowed"

Run with sudo:

```bash
sudo security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -P "your-password" \
  -o ~/Desktop/developer_id.p12 \
  "Developer ID Application: Aurodent CZ, s.r.o."
```

### "The specified item could not be found in the keychain"

Try using the hash instead of the name:

```bash
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities \
  -f pkcs12 \
  -P "your-password" \
  -o ~/Desktop/developer_id.p12 \
  B189E89A9BC71C14E0C72C107C5209D540AB5336
```

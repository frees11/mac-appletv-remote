# App Icon Setup

This directory contains all the icon assets for the ATV Remote application.

## Source Icon

**File:** `../atv remote v2.1.svg`
- Original SVG icon file
- Used as the source for all platform-specific icons

## Generated Icons

These files are **automatically generated** from the SVG source using `scripts/generate-icons.sh`:

### macOS
- `icon.icns` - App icon for macOS (includes multiple resolutions)
- `tray-iconTemplate.png` - Menu bar icon (22x22)
- `tray-iconTemplate@2x.png` - Menu bar icon for Retina displays (44x44)

### Windows
- `icon.ico` - App icon for Windows (multiple sizes in one file)
- `tray-icon.png` - System tray icon (256x256)

### Linux
- `icon.png` - App icon for Linux (512x512)
- `tray-icon.png` - System tray icon (256x256)

### PNG Exports
All exported PNG files are stored in `icons/png/`:
- 16x16, 32x32, 48x48, 64x64, 128x128, 256x256, 512x512, 1024x1024

## Regenerating Icons

Icons are automatically generated during the build process, but you can manually regenerate them:

```bash
# Manual generation
./scripts/generate-icons.sh

# Or via npm
npm run icons
```

Icons are automatically generated when you:
- Run `npm run build`
- Run `npm run electron:build`
- Run `make build`
- Run `make deploy`

## Icon Usage in App

### Application Window
The main window icon is set in `electron/main.js`:
```javascript
icon: path.join(__dirname, '../build/icon.png')
```

### Menu Bar / System Tray
- **macOS**: Uses `tray-iconTemplate.png` (Template suffix for dark/light mode support)
- **Windows/Linux**: Uses `tray-icon.png`

### Packaged App
Configured in `electron-builder.yml` and `package.json`:
```yaml
mac:
  icon: build/icon.icns
win:
  icon: build/icon.ico
linux:
  icon: build/icon.png
```

## Updating the Icon

To use a different icon:

1. Replace `atv remote v2.1.svg` with your new SVG file
2. Update the path in `scripts/generate-icons.sh` if the filename changes
3. Run `npm run icons` to regenerate all formats
4. Test the app in development mode: `npm run electron:dev`

## Requirements

**ImageMagick** is required for icon generation:

```bash
# macOS
brew install imagemagick

# Ubuntu/Debian
sudo apt-get install imagemagick

# Windows
# Download from: https://imagemagick.org/script/download.php
```

## Troubleshooting

### Icons not showing in development
- Ensure icons are generated: `npm run icons`
- Check file paths in `electron/main.js`
- Verify files exist in `build/` directory

### Icons not showing in built app
- Check `electron-builder.yml` configuration
- Ensure icons are generated before build
- Verify `buildResources` directory is set to `build`

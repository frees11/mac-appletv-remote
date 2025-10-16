#!/bin/bash

# Icon Generation Script for ATV Remote
# Converts SVG to all required formats for Electron app

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎨 Generating app icons from SVG...${NC}"
echo ""

# Paths
SVG_SOURCE="atv remote v2.1.svg"
BUILD_DIR="build"
ICON_DIR="$BUILD_DIR/icons"

# Check if SVG exists
if [ ! -f "$SVG_SOURCE" ]; then
    echo -e "${YELLOW}⚠️  Error: SVG file not found: $SVG_SOURCE${NC}"
    exit 1
fi

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo -e "${YELLOW}⚠️  ImageMagick is not installed${NC}"
    echo "Install it with: brew install imagemagick"
    exit 1
fi

# Create directories
mkdir -p "$ICON_DIR"
mkdir -p "$ICON_DIR/mac"
mkdir -p "$ICON_DIR/win"
mkdir -p "$ICON_DIR/png"

echo -e "${GREEN}📁 Creating icon directories...${NC}"

# Generate PNG files at various sizes
echo -e "${GREEN}🖼️  Generating PNG files...${NC}"

sizes=(16 32 48 64 128 256 512 1024)
for size in "${sizes[@]}"; do
    echo "  - ${size}x${size}px"
    convert -background none -resize "${size}x${size}" "$SVG_SOURCE" "$ICON_DIR/png/icon_${size}x${size}.png"
done

# Generate macOS .icns file
echo -e "${GREEN}🍎 Generating macOS .icns file...${NC}"

# Create iconset folder
ICONSET="$ICON_DIR/mac/icon.iconset"
mkdir -p "$ICONSET"

# Copy PNGs to iconset with proper naming
cp "$ICON_DIR/png/icon_16x16.png" "$ICONSET/icon_16x16.png"
cp "$ICON_DIR/png/icon_32x32.png" "$ICONSET/icon_16x16@2x.png"
cp "$ICON_DIR/png/icon_32x32.png" "$ICONSET/icon_32x32.png"
cp "$ICON_DIR/png/icon_64x64.png" "$ICONSET/icon_32x32@2x.png"
cp "$ICON_DIR/png/icon_128x128.png" "$ICONSET/icon_128x128.png"
cp "$ICON_DIR/png/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICON_DIR/png/icon_256x256.png" "$ICONSET/icon_256x256.png"
cp "$ICON_DIR/png/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICON_DIR/png/icon_512x512.png" "$ICONSET/icon_512x512.png"
cp "$ICON_DIR/png/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

# Create .icns file
iconutil -c icns "$ICONSET" -o "$BUILD_DIR/icon.icns"
echo "  ✓ Created: $BUILD_DIR/icon.icns"

# Clean up iconset folder
rm -rf "$ICONSET"

# Generate Windows .ico file
echo -e "${GREEN}🪟 Generating Windows .ico file...${NC}"
convert "$ICON_DIR/png/icon_16x16.png" \
        "$ICON_DIR/png/icon_32x32.png" \
        "$ICON_DIR/png/icon_48x48.png" \
        "$ICON_DIR/png/icon_256x256.png" \
        "$BUILD_DIR/icon.ico"
echo "  ✓ Created: $BUILD_DIR/icon.ico"

# Copy main PNG for Linux
echo -e "${GREEN}🐧 Setting up Linux icon...${NC}"
cp "$ICON_DIR/png/icon_512x512.png" "$BUILD_DIR/icon.png"
echo "  ✓ Created: $BUILD_DIR/icon.png"

# Copy 256px for tray icon
cp "$ICON_DIR/png/icon_256x256.png" "$BUILD_DIR/tray-icon.png"
echo "  ✓ Created: $BUILD_DIR/tray-icon.png (for menu bar)"

# Create Template icon for macOS menu bar (monochrome)
echo -e "${GREEN}📱 Generating macOS menu bar template icon...${NC}"
convert -background none -resize "22x22" "$SVG_SOURCE" "$BUILD_DIR/tray-iconTemplate.png"
convert -background none -resize "44x44" "$SVG_SOURCE" "$BUILD_DIR/tray-iconTemplate@2x.png"
echo "  ✓ Created: $BUILD_DIR/tray-iconTemplate.png"
echo "  ✓ Created: $BUILD_DIR/tray-iconTemplate@2x.png"

echo ""
echo -e "${GREEN}✅ Icon generation complete!${NC}"
echo ""
echo "Generated files:"
echo "  • $BUILD_DIR/icon.icns (macOS)"
echo "  • $BUILD_DIR/icon.ico (Windows)"
echo "  • $BUILD_DIR/icon.png (Linux)"
echo "  • $BUILD_DIR/tray-icon.png (Menu bar)"
echo "  • $BUILD_DIR/tray-iconTemplate.png (macOS menu bar)"
echo "  • $ICON_DIR/png/*.png (All sizes)"

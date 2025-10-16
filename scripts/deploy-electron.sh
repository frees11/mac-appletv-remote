#!/bin/bash

# Deploy ATV Remote Electron App
# This script builds and signs the macOS Electron app for distribution

set -e  # Exit on error

echo "🚀 Starting ATV Remote Electron build and deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables from .env.deploy if it exists
if [ -f ".env.deploy" ]; then
    echo -e "${BLUE}📄 Loading environment variables from .env.deploy${NC}"
    set -a  # automatically export all variables
    source .env.deploy
    set +a
else
    echo -e "${YELLOW}ℹ️  No .env.deploy file found. Code signing will be skipped.${NC}"
    echo -e "${YELLOW}   Create .env.deploy from .env.deploy.example for code signing.${NC}"
fi

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ Error: This script must run on macOS${NC}"
    exit 1
fi

# Check required environment variables for code signing
if [ -z "$NOTARIZE_APPLE_ID" ] && [ -z "$APPLE_ID" ]; then
    echo -e "${YELLOW}⚠️  Warning: Notarization credentials not set in .env.deploy${NC}"
    echo "Continuing with code signing only (no notarization)..."
    echo ""
else
    echo -e "${GREEN}✅ Notarization credentials loaded${NC}"
fi

# Step 1: Clean previous builds
echo -e "${GREEN}📦 Cleaning previous builds...${NC}"
rm -rf dist
rm -rf dist-electron
rm -rf .output

# Step 2: Install/update dependencies
echo -e "${GREEN}📥 Installing dependencies...${NC}"
# Use npm install instead of npm ci to avoid node_modules conflicts
npm install

# Step 3: Build standalone backend
echo -e "${GREEN}🐍 Building standalone backend...${NC}"
./scripts/build-backend.sh

# Step 4: Generate icons
echo -e "${GREEN}🎨 Generating icons...${NC}"
./scripts/generate-icons.sh

# Step 5: Build frontend
echo -e "${GREEN}🏗️  Building frontend...${NC}"
npm run build

# Step 6: Build Electron app with code signing
echo -e "${GREEN}⚡ Building Electron app for macOS...${NC}"

# Export environment variables for electron-builder
export CSC_IDENTITY_AUTO_DISCOVERY=true

# Build for macOS
npm run electron:build -- --mac

echo -e "${GREEN}✅ Build complete!${NC}"

# Step 7: Display build artifacts
echo ""
echo -e "${GREEN}📦 Build artifacts:${NC}"
ls -lh dist-electron/*.dmg 2>/dev/null || echo "No DMG files found"
ls -lh dist-electron/*.zip 2>/dev/null || echo "No ZIP files found"

# Step 8: Upload to distribution service (optional)
if [ -n "$UPLOAD_TO_S3" ]; then
    echo -e "${GREEN}☁️  Uploading to distribution service...${NC}"
    # Add your upload logic here (S3, FTP, etc.)
    # Example: aws s3 cp dist-electron/*.dmg s3://your-bucket/releases/
fi

echo ""
echo -e "${GREEN}✨ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Test the app in dist-electron/"
echo "  2. Share the .dmg or .zip file with your colleague"
echo "  3. For auto-updates, consider setting up a release server"

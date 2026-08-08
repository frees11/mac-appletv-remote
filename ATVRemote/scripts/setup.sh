#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ATV Remote SwiftUI Setup ==="

echo ""
echo "Step 1: Checking dependencies..."

MISSING_DEPS=()

if ! command -v protoc &> /dev/null; then
    MISSING_DEPS+=("protobuf")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "Missing dependencies: ${MISSING_DEPS[*]}"
    echo "Installing with Homebrew..."
    brew install ${MISSING_DEPS[*]}
fi

if ! command -v swift-protobuf &> /dev/null 2>&1; then
    echo "Installing swift-protobuf..."
    brew install swift-protobuf
fi

echo "All dependencies installed!"

echo ""
echo "Step 2: Generating protobuf Swift code..."
"$SCRIPT_DIR/generate-protos.sh"

echo ""
echo "Step 3: Building Swift Package..."
cd "$PROJECT_DIR/Packages/ATVRemoteCore"
swift build

echo ""
echo "Step 4: Opening Xcode..."
echo "To open the project, run:"
echo "  open $PROJECT_DIR"
echo ""
echo "Then in Xcode:"
echo "  1. File > New > Project"
echo "  2. Choose 'App' under macOS"
echo "  3. Name it 'ATVRemote'"
echo "  4. Save in: $PROJECT_DIR"
echo "  5. Add local package: Packages/ATVRemoteCore"
echo ""
echo "Or use the provided project file if available."

echo ""
echo "=== Setup Complete ==="

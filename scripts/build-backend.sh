#!/bin/bash

# Build standalone Python backend executable using PyInstaller
# This bundles Python and all dependencies into a single executable

set -e

echo "🐍 Building standalone Python backend..."
echo ""

# Check if we're in the project root
if [ ! -d "backend" ]; then
    echo "❌ Error: Must run from project root"
    exit 1
fi

cd backend

# Activate virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate

# Install PyInstaller if not present
if ! pip show pyinstaller > /dev/null 2>&1; then
    echo "📦 Installing PyInstaller..."
    pip install pyinstaller
fi

# Ensure all dependencies are installed
echo "📦 Installing backend dependencies..."
pip install -r requirements.txt

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build dist __pycache__

# Build with PyInstaller
echo "🔨 Building backend executable..."
pyinstaller backend.spec

# Check if build succeeded (onedir creates a directory with executable inside)
if [ -f "dist/atv-backend/atv-backend" ]; then
    echo ""
    echo "✅ Backend built successfully!"
    echo "📁 Bundle: backend/dist/atv-backend/"
    echo "📁 Executable: backend/dist/atv-backend/atv-backend"
    echo ""

    # Make executable
    chmod +x dist/atv-backend/atv-backend

    # Remove quarantine attribute from all files
    echo "🔓 Removing quarantine attributes..."
    xattr -cr dist/atv-backend || true

    # Code sign all binaries in the bundle (onedir mode)
    echo "🔐 Code signing backend bundle..."

    # Sign all dylibs and frameworks first
    find dist/atv-backend -type f \( -name "*.dylib" -o -name "*.so" \) -exec codesign --force --sign - {} \; 2>/dev/null || true

    # Sign the main executable
    codesign --force --sign - \
      --deep \
      --options runtime \
      dist/atv-backend/atv-backend

    echo "✅ Backend bundle signed successfully"

    echo ""
    echo "✅ Backend ready for packaging!"
else
    echo ""
    echo "❌ Build failed! Expected: dist/atv-backend/atv-backend"
    ls -la dist/ 2>/dev/null || echo "dist/ directory not found"
    exit 1
fi

deactivate
cd ..

echo ""
echo "✅ Backend ready for bundling with Electron app"

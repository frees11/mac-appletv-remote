#!/bin/bash

# Install Python dependencies for ATV Remote backend
# This is needed for the built/production app to work

set -e

echo "🐍 Installing Python dependencies for ATV Remote..."
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed!"
    echo ""
    echo "Please install Python 3.9+ first:"
    echo "  brew install python@3.11"
    echo ""
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "✅ Found Python $PYTHON_VERSION"
echo ""

# Install dependencies
echo "📦 Installing backend dependencies..."
pip3 install --user fastapi==0.109.2 uvicorn==0.27.1 pyatv==0.14.5 websockets==12.0 python-dotenv==1.0.1

echo ""
echo "✅ Installation complete!"
echo ""
echo "You can now run the built ATV Remote app."
echo "The backend will start automatically when you open the app."

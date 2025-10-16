#!/bin/bash

# ATV Remote - Automatic Setup Script
# This script automatically sets up the environment without user interaction

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backend"

echo "🚀 ATV Remote - Automatic Setup"
echo "================================"

# Create .env files if they don't exist
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "📝 Creating .env file..."
    cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
fi

if [ ! -f "$BACKEND_DIR/.env" ]; then
    echo "📝 Creating backend/.env file..."
    cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
fi

# Check if Python virtual environment exists
if [ ! -d "$BACKEND_DIR/venv" ]; then
    echo "🐍 Creating Python virtual environment..."

    # Try different Python commands
    if command -v python3 &> /dev/null; then
        PYTHON_CMD=python3
    elif command -v python &> /dev/null; then
        PYTHON_CMD=python
    else
        echo "❌ Error: Python not found. Please install Python 3.9 or higher."
        exit 1
    fi

    # Create virtual environment
    $PYTHON_CMD -m venv "$BACKEND_DIR/venv"

    # Install dependencies
    echo "📦 Installing Python dependencies..."
    source "$BACKEND_DIR/venv/bin/activate"
    pip install --upgrade pip
    pip install -r "$BACKEND_DIR/requirements.txt"
    deactivate

    echo "✅ Python environment setup complete"
else
    echo "✅ Python virtual environment already exists"
fi

echo ""
echo "✅ Setup complete! The app is ready to use."

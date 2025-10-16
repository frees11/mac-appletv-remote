.PHONY: help install setup run dev backend frontend electron build clean test deploy

# Default target
help:
	@echo "ATV Remote - Available Commands:"
	@echo ""
	@echo "  make install    - Install all dependencies (npm + pip)"
	@echo "  make setup      - Install dependencies and setup environment files"
	@echo "  make run        - Run the Electron app (single command)"
	@echo "  make dev        - Run frontend dev server only"
	@echo "  make backend    - Run backend server only"
	@echo "  make electron   - Run Electron app only"
	@echo "  make build      - Build Electron app for distribution"
	@echo "  make deploy     - Build and deploy app (code signing if configured)"
	@echo "  make clean      - Clean build artifacts and dependencies"
	@echo "  make test       - Run tests (backend)"
	@echo ""

# Install all dependencies
install:
	@echo "Installing frontend dependencies..."
	npm install
	@echo "Creating Python virtual environment..."
	cd backend && python3 -m venv venv
	@echo "Installing backend dependencies..."
	cd backend && ./venv/bin/pip install -r requirements.txt
	@echo "✅ All dependencies installed!"

# Setup environment files
setup: install
	@echo "Setting up environment files..."
	@if [ ! -f .env ]; then cp .env.example .env; echo "Created .env"; fi
	@if [ ! -f backend/.env ]; then cp backend/.env.example backend/.env; echo "Created backend/.env"; fi
	@echo "✅ Setup complete!"

# Run the full application (Electron + Backend)
run:
	@echo "🚀 Starting ATV Remote..."
	npm run electron:dev

# Run frontend dev server only
dev:
	@echo "Starting frontend dev server..."
	npm run dev

# Run backend server only
backend:
	@echo "Starting backend server..."
	cd backend && ./venv/bin/python3 main.py

# Run Electron only (requires frontend to be running)
electron:
	@echo "Starting Electron..."
	npx electron .

# Build for distribution
build:
	@echo "Building Electron app..."
	./scripts/build-backend.sh
	./scripts/generate-icons.sh
	npm run build
	npm run electron:build
	@echo "✅ Build complete! Check dist-electron/ directory"

# Build for specific platform
build-mac:
	@echo "Building for macOS..."
	npm run electron:build -- --mac

build-win:
	@echo "Building for Windows..."
	npm run electron:build -- --win

build-linux:
	@echo "Building for Linux..."
	npm run electron:build -- --linux

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf node_modules
	rm -rf backend/__pycache__
	rm -rf backend/app/__pycache__
	rm -rf dist
	rm -rf dist-electron
	rm -rf .output
	rm -f credentials.json
	@echo "✅ Cleaned!"

# Clean everything including dependencies
clean-all: clean
	@echo "Removing dependencies..."
	rm -rf backend/venv
	rm -rf backend/env
	@echo "✅ All cleaned!"

# Test backend
test:
	@echo "Running backend tests..."
	cd backend && python3 -m pytest

# Format code
format:
	@echo "Formatting code..."
	npm run lint:fix || true
	cd backend && black . || true
	@echo "✅ Code formatted!"

# Quick start (install + setup + run)
start: setup run

# Deploy for distribution
deploy:
	@echo "🚀 Deploying ATV Remote..."
	./scripts/deploy-electron.sh

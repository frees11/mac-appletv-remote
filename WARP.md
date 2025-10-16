# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

ATV Remote is a multiplatform Apple TV remote control app built with:
- **Frontend**: Vue 3 + TypeScript + Tailwind CSS
- **Desktop**: Electron with system tray integration
- **Backend**: FastAPI + pyatv library for Apple TV communication
- **Communication**: WebSocket + REST API

The app provides full remote control functionality, device discovery, pairing support, and real-time playback information through a touch-friendly interface.

## Development Commands

### Quick Start
```bash
# Install all dependencies and setup environment
make setup

# Run the full Electron app (frontend + backend)
make run
# or
npm run electron:dev
```

### Individual Components
```bash
# Frontend only (Vue dev server)
npm run dev

# Backend only (FastAPI server)
npm run backend:dev
# or
make backend

# Backend with virtual environment
cd backend && ./venv/bin/python3 main.py
```

### Building
```bash
# Build for distribution (all platforms)
npm run electron:build
# or
make build

# Platform-specific builds
make build-mac
make build-win  
make build-linux

# Build backend executable only
npm run backend:build
# or
./scripts/build-backend.sh
```

### Deployment
```bash
# Quick deploy for beta testing
make deploy

# Release with version bump
./scripts/release.sh
```

### Utilities
```bash
# Generate icons from SVG
npm run icons
# or
./scripts/generate-icons.sh

# Format code
make format
```

## Architecture

### Multi-Process Application
The app consists of three main processes:
1. **Electron Main Process** (`electron/main.js`) - Manages backend process, window, and system integration
2. **Frontend Process** (`src/`) - Vue 3 app with remote control UI
3. **Backend Process** (`backend/main.py`) - FastAPI server handling Apple TV communication

### Backend (Python)
- **Entry Point**: `backend/main.py` - FastAPI app with CORS, health endpoints
- **API Structure**: 
  - `app/api/devices.py` - Device discovery and pairing
  - `app/api/control.py` - Remote control commands
  - `app/ws/websocket.py` - WebSocket for real-time communication
- **Key Service**: `app/services/atv_service.py` - Core Apple TV connection management using pyatv
- **Build**: Uses PyInstaller to create standalone executable (`backend.spec`)

### Frontend (Vue 3 + TypeScript)
- **Entry Point**: `src/main.ts`
- **Key Views**:
  - `src/views/DeviceList.vue` - Device discovery and pairing UI
  - `src/views/RemoteControl.vue` - Main remote control interface
- **Composables**:
  - `src/composables/useApi.ts` - REST API wrapper
  - `src/composables/useWebSocket.ts` - WebSocket connection management
- **Types**: `src/types/index.ts` - Shared TypeScript interfaces

### Electron Integration
- **Main Process**: Spawns Python backend, manages window lifecycle, system tray
- **Development Mode**: Uses Python from venv, loads from Vite dev server
- **Production Mode**: Uses PyInstaller-bundled executable, loads from built files
- **Global Shortcuts**: Cmd+Shift+R (Mac) / Ctrl+Shift+R (Win/Linux) to toggle window

## Key Development Patterns

### Backend Communication
- REST API for device management and one-off commands
- WebSocket (`/ws/control`) for real-time control and playback updates
- Backend spawned as child process by Electron, communicates via localhost:8000

### Adding New Remote Commands
1. Add action to `RemoteAction` type in `src/types/index.ts`
2. Add button/handler in `src/views/RemoteControl.vue`  
3. Add backend handler in `backend/app/services/atv_service.py`

### Development Workflow
- Frontend auto-reloads via Vite HMR
- Backend requires restart for changes
- Use `make run` for full-stack development
- Access API docs at `http://localhost:8000/docs`

### Build Process
- Icons auto-generated from `atv remote v2.1.svg` for all platforms
- Backend bundled into standalone executable via PyInstaller
- Electron-builder creates platform-specific installers (.dmg, .exe, .AppImage)
- Code signing integrated for macOS distribution

### Environment Configuration
- `.env` - Frontend environment variables
- `backend/.env` - Backend configuration (HOST, PORT, CORS_ORIGINS)
- Separate development and production CORS settings

## Testing

### Manual Testing Checklist
- Device discovery functionality
- Pairing flow completion
- All remote button responses
- WebSocket reconnection on disconnect
- Now playing info updates
- Global keyboard shortcuts
- System tray functionality
- Clean app termination

### Backend Testing
```bash
# Health check
curl http://localhost:8000/health

# API documentation
open http://localhost:8000/docs
```

## Common Issues

### Backend Startup
- Ensure Python 3.9+ is available
- Check virtual environment: `cd backend && source venv/bin/activate`
- Verify pyatv installation: `pip install -r backend/requirements.txt`
- Port conflicts: modify PORT in `backend/.env`

### Device Discovery
- Ensure same network connectivity
- Check firewall settings
- Apple TV may require multiple pairing attempts
- Some Apple TVs need to be awakened before discovery

### Build Issues
- Run `make clean` to clear build artifacts
- Ensure backend builds successfully before Electron build
- macOS signing requires developer certificate configuration
- Windows builds may require additional Visual C++ dependencies

## File Structure Notes

- `backend/app/` - FastAPI application modules
- `src/composables/` - Vue 3 reusable logic
- `scripts/` - Build and deployment automation
- `build/` - Icon generation and build configuration
- `docs/` - Detailed deployment and setup guides
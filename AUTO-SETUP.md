# Automatic Setup Documentation

## Overview

ATV Remote includes an automatic setup system that eliminates manual configuration. The app handles all dependencies and configuration automatically on first launch.

## How It Works

### Development Mode

When you run `npm run electron:dev` for the first time:

1. **Environment Files** (`electron/main.js:runAutoSetup()`)
   - Checks if `.env` exists in project root
   - If not, copies from `.env.example`
   - Checks if `backend/.env` exists
   - If not, copies from `backend/.env.example`

2. **Python Virtual Environment** (`electron/main.js:runAutoSetup()`)
   - Checks if `backend/venv/` exists
   - If not:
     - Finds Python executable (tries `python3`, then `python`)
     - Creates virtual environment with `python3 -m venv backend/venv`
     - Upgrades pip
     - Installs requirements from `backend/requirements.txt`

3. **Backend Server** (`electron/main.js:startBackend()`)
   - Spawns Python backend using `backend/venv/bin/python3`
   - Passes environment variables (HOST, PORT, CORS_ORIGINS)
   - Monitors stdout/stderr for debugging

4. **Health Check** (`electron/main.js:waitForBackend()`)
   - Waits up to 30 seconds for backend to be ready
   - Polls `/health` endpoint every 1 second
   - Only opens main window after backend is confirmed ready

### Production Mode (Built App)

When you double-click the `.app` file:

1. **Environment Files**
   - Copies `.env.example` to user data directory if needed
   - Creates `backend.env` in user data directory
   - Location: `~/Library/Application Support/ATV Remote/` (macOS)

2. **Backend Binary**
   - Uses pre-built PyInstaller binary (no Python needed)
   - Binary location: `Resources/app.asar.unpacked/backend/dist/atv-backend/atv-backend`
   - Automatically starts with proper environment variables

3. **Health Check**
   - Same as development mode
   - Ensures backend is ready before showing UI

## File Locations

### Development

```
project-root/
├── .env                          # Auto-created from .env.example
├── backend/
│   ├── .env                      # Auto-created from backend/.env.example
│   └── venv/                     # Auto-created Python virtual environment
│       ├── bin/
│       │   ├── python3
│       │   └── pip
│       └── lib/
```

### Production (macOS)

```
~/Library/Application Support/ATV Remote/
├── .env                          # User-specific settings
└── backend.env                   # Backend configuration

/Applications/ATV Remote.app/Contents/
├── Resources/
│   ├── .env.example              # Template for .env
│   ├── backend/
│   │   └── .env.example          # Template for backend.env
│   └── app.asar.unpacked/
│       └── backend/
│           └── dist/
│               └── atv-backend/
│                   └── atv-backend  # Pre-built backend binary
```

## Error Handling

### Python Not Found (Development)

If Python is not installed:
- Shows error dialog: "Python 3.9 or higher is required"
- Suggests installing from python.org
- Quits app gracefully

### Backend Failed to Start

If backend doesn't respond to health check:
- Shows error dialog: "Backend server could not be started"
- Logs full error to console
- Quits app gracefully

### Environment File Missing (Production)

If `.env.example` files are not bundled:
- Logs warning to console
- Continues with default configuration
- Backend uses fallback environment variables

## Customization

### Disabling Auto-Setup

To disable automatic setup in development:

```javascript
// electron/main.js
app.whenReady().then(async () => {
  // Comment out:
  // const setupSuccess = await runAutoSetup()

  // Directly start backend:
  const backendStarted = startBackend()
  // ... rest of code
})
```

### Changing Default Ports

Edit `.env.example` before building:

```
VITE_API_URL=http://localhost:9000
VITE_WS_URL=ws://localhost:9000/ws/control
```

And `backend/.env.example`:

```
HOST=127.0.0.1
PORT=9000
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

## Build Process Integration

The automatic setup integrates with the build process:

### `package.json` Scripts

```json
{
  "prebuild": "npm run backend:build && npm run icons",
  "preelectron:build": "npm run backend:build && npm run icons"
}
```

- `backend:build` creates the standalone binary
- `icons` generates all platform-specific icons

### `electron-builder.yml`

```yaml
files:
  - dist/**/*
  - electron/**/*
  - backend/dist/atv-backend/**/*
  - package.json
  - .env.example          # ← Included in bundle
  - backend/.env.example  # ← Included in bundle

asarUnpack:
  - backend/dist/atv-backend/**/*  # Backend must be unpacked
```

## Testing Auto-Setup

### Test Development Auto-Setup

```bash
# Remove existing setup
rm .env
rm backend/.env
rm -rf backend/venv

# Run app - should auto-setup everything
npm run electron:dev
```

### Test Production Auto-Setup

```bash
# Build the app
npm run electron:build

# Open the built app
open dist-electron/mac-arm64/ATV\ Remote.app

# Check logs in Console.app for setup messages
```

### Verify Setup

Development:
```bash
# Check .env files exist
ls -la .env backend/.env

# Check venv exists
ls -la backend/venv/bin/python3

# Check backend is running
curl http://localhost:8000/health
```

Production:
```bash
# Check user data directory
ls -la ~/Library/Application\ Support/ATV\ Remote/

# Check backend process
ps aux | grep atv-backend
```

## Troubleshooting

### Auto-setup seems stuck

Check console logs for:
- Python installation errors
- Permission errors creating venv
- Network issues downloading packages

### Backend starts but health check fails

- Check if port 8000 is already in use: `lsof -i :8000`
- Check backend logs in console output
- Verify Python dependencies are installed

### Production app won't start

- Check Console.app for error messages
- Verify backend binary is in app bundle
- Check code signing and notarization (macOS)

## Future Improvements

Potential enhancements:

1. **Progress Dialog** - Show setup progress in GUI instead of console
2. **Dependency Updates** - Auto-update Python packages on app update
3. **Settings UI** - Allow users to change ports and settings from GUI
4. **Multi-Backend** - Support different Python versions automatically
5. **Portable Mode** - Option to store settings next to app instead of user directory

# ATV Remote - Multiplatform

A modern, multiplatform remote control for Apple TV built with Vue 3, Electron, and FastAPI.

**Zero Configuration Required** - Just double-click to launch! Everything is set up automatically.

## Features

- **Zero Setup**: Double-click the app and start using it immediately - no manual configuration needed
- **Full Remote Control**: Navigate, play/pause, volume control, and more
- **Device Discovery**: Automatically find Apple TVs on your network
- **Pairing Support**: Secure pairing with your Apple TV
- **Now Playing Info**: See what's currently playing
- **Real-time Control**: WebSocket-based instant response
- **Keyboard Shortcuts**: Quick access with global shortcuts
- **Menu Bar App**: Lives in your system tray for easy access
- **Cross-platform**: Works on macOS, Windows, and Linux

## Tech Stack

- **Frontend**: Vue 3 + TypeScript + Tailwind CSS
- **Desktop**: Electron
- **Backend**: FastAPI + pyatv
- **Communication**: WebSocket + REST API

## Custom Icon

The app uses a custom ATV icon (`atv remote v2.1.svg`) that's automatically converted to all platform-specific formats:
- **macOS**: App icon (.icns) and menu bar icon (Template)
- **Windows**: App icon (.ico) and system tray icon
- **Linux**: App icon and system tray icon

Icons are automatically generated during the build process. See [docs/ICON-SETUP.md](docs/ICON-SETUP.md) for details.

## Quick Start (For End Users)

### Download and Run

1. Download the latest release for your platform
2. Double-click the `.app` (macOS) / `.exe` (Windows) / `.AppImage` (Linux)
3. That's it! The app handles all setup automatically

**No Python, no dependencies, no configuration required!**

See [FIRST-TIME-SETUP.md](FIRST-TIME-SETUP.md) for detailed information.

## Prerequisites (For Developers Only)

- Node.js 18+ and npm
- Python 3.9+ (auto-setup will install dependencies)
- An Apple TV on the same network

## Installation (For Developers)

### Automatic Setup (Recommended)

Simply run:

```bash
npm ci
npm run electron:dev
```

The app will automatically:
- Create `.env` files from examples
- Set up Python virtual environment
- Install all dependencies
- Start the development server

### Manual Setup (Optional)

If you prefer manual control:

```bash
# Install frontend dependencies
npm ci

# Copy environment files (optional - auto-created on first run)
cp .env.example .env
cp backend/.env.example backend/.env

# Set up Python environment (optional - auto-created on first run)
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..
```

## Development

### Run Backend Only

```bash
npm run backend:dev
```

The backend will start on `http://localhost:8000`

### Run Frontend Only

```bash
npm run dev
```

The frontend will start on `http://localhost:5173`

### Run Electron App (Full Stack)

```bash
# Terminal 1: Start frontend dev server
npm run dev

# Terminal 2: Start Electron with backend
npm run electron:dev
```

Or use the combined command:

```bash
npm run electron:dev
```

This will:
1. Start the Vite dev server
2. Launch Electron
3. Automatically start the Python backend

## Building

Build the Electron app for distribution:

```bash
npm run electron:build
```

This creates installers in the `dist-electron` directory:
- **macOS**: `.dmg` and `.zip`
- **Windows**: `.exe` installer
- **Linux**: `.AppImage` and `.deb`

## Deployment

### Quick Deploy for Beta Testing

Share your app with colleagues for testing:

```bash
make deploy
```

This builds a signed (if configured) `.dmg` file ready for distribution.

**See guides for more:**
- [Quick Start Deployment](docs/QUICK-START-DEPLOYMENT.md) - Ship to beta testers in 5 minutes
- [Full Deployment Guide](DEPLOYMENT.md) - All deployment options explained
- [CI/CD Setup](docs/CICD.md) - Automated builds with GitHub Actions

### Automatic Releases

**Version automatically increments on every push to main!**

Just push your code:
```bash
git add .
git commit -m "feat: your changes"
git push origin main
```

GitHub Actions automatically:
- Increments version (1.0.0 → 1.0.1)
- Builds the app (~10-15 min)
- Creates GitHub Release with DMG files

**See:** [.github/AUTO_RELEASE.md](.github/AUTO_RELEASE.md) for details

### Manual Release (Alternative)

For custom versions or release notes:

```bash
./scripts/release.sh
```

This interactive script:
1. Updates version number
2. Creates git tag
3. Pushes to repository
4. Triggers automated build

## Usage

### First Time Setup

1. Launch the app
2. Click "Scan Devices" to find Apple TVs
3. Click on your Apple TV to start pairing
4. Enter the PIN shown on your TV
5. Once paired, you're ready to control your Apple TV!

### Keyboard Shortcuts

- **Cmd+Shift+R** (Mac) / **Ctrl+Shift+R** (Win/Linux): Toggle remote window

### Remote Control

- **Touchpad**: Click on edges for navigation (up/down/left/right), click center to select
- **Menu Button**:
  - Short press: Go back one screen
  - Long press (hold for 0.6s): Return to home screen/springboard
- **Keyboard Shortcuts**:
  - Arrow keys: Navigate (up/down/left/right)
  - Enter/Space: Select
  - Escape: Menu/Back
  - H: Home (springboard)
  - M: Menu
  - P: Play/Pause
- **Control Buttons**:
  - Power: Sleep/Wake Apple TV
  - Back: Return to previous screen (long press for home)
  - TV: Go to TV app
  - Play/Pause: Control playback
  - Mute: Toggle audio
  - Volume +/-: Adjust volume

## API Documentation

When running, visit `http://localhost:8000/docs` for the interactive API documentation.

### Key Endpoints

- `GET /api/devices` - List discovered Apple TVs
- `POST /api/devices/{id}/pair` - Pair with a device
- `POST /api/control/command` - Send remote command
- `GET /api/control/{id}/playing` - Get playback info
- `WS /ws/control` - WebSocket for real-time control

## Project Structure

```
atv-remote/
├── backend/              # FastAPI backend
│   ├── app/
│   │   ├── api/         # REST endpoints
│   │   ├── ws/          # WebSocket handlers
│   │   ├── services/    # pyatv integration
│   │   └── models/      # Data models
│   └── main.py          # Backend entry point
├── electron/            # Electron main process
│   ├── main.js          # Main window & backend spawning
│   └── preload.js       # IPC bridge
├── src/                 # Vue 3 frontend
│   ├── components/      # UI components
│   ├── composables/     # Reusable logic
│   ├── views/           # Page components
│   └── main.ts          # Frontend entry point
└── package.json         # Project config
```

## Troubleshooting

### Backend won't start

- Make sure Python 3.9+ is installed
- Install dependencies: `pip install -r backend/requirements.txt`
- Check if port 8000 is available

### Can't find Apple TV

- Ensure your computer and Apple TV are on the same network
- Check firewall settings
- Try restarting your Apple TV

### Pairing fails

- Make sure you're entering the correct PIN
- Some Apple TVs require multiple pairing attempts
- Try restarting both devices

## License

MIT

## Credits

Built with:
- [pyatv](https://pyatv.dev/) - Apple TV library
- [Vue 3](https://vuejs.org/) - Frontend framework
- [Electron](https://www.electronjs.org/) - Desktop framework
- [FastAPI](https://fastapi.tiangolo.com/) - Backend framework

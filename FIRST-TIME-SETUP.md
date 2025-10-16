# First-Time Setup Guide

ATV Remote is designed to work automatically without any manual setup. Just double-click the `.app` file and everything will be configured for you!

## What Happens Automatically

When you launch ATV Remote for the first time, the app will:

1. **Create Environment Files** - Automatically copy `.env.example` files to create working configuration
2. **Start Backend Server** - Launch the Python backend server that communicates with Apple TV
3. **Open Main Window** - Display the remote control interface

## For Production (Built App)

### macOS

1. Download the `.dmg` file
2. Open the `.dmg` and drag `ATV Remote.app` to Applications
3. Double-click `ATV Remote.app` to launch
4. That's it! The app handles everything automatically

The backend binary is pre-built and bundled with the app, so you don't need Python installed.

### First Launch

On first launch, you'll see:
- The app icon in your menu bar
- The remote control window
- A "Scan Devices" button to find your Apple TV

Simply click "Scan Devices" and select your Apple TV to get started!

## For Development

### Requirements

- Node.js 18+ and npm
- Python 3.9+ (for backend development)
- An Apple TV on the same network

### Automatic Setup (Recommended)

Just run:

```bash
npm run electron:dev
```

The app will automatically:
1. Create `.env` files from examples
2. Set up Python virtual environment (if needed)
3. Install Python dependencies (if needed)
4. Start the development server

### Manual Setup (Optional)

If you prefer to set things up manually:

```bash
# Install Node dependencies
npm ci

# Create environment files
cp .env.example .env
cp backend/.env.example backend/.env

# Set up Python environment
cd backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cd ..

# Run development
npm run dev                # Terminal 1: Frontend
npm run backend:dev        # Terminal 2: Backend
npm run electron:dev       # Terminal 3: Electron
```

## Building for Distribution

Build a production-ready app:

```bash
npm run electron:build
```

This will:
1. Build the backend binary
2. Generate all required icons
3. Build the frontend
4. Create a distributable `.dmg` (macOS), `.exe` (Windows), or `.AppImage` (Linux)

Output will be in `dist-electron/` directory.

## Troubleshooting

### "Python Not Found" Error (Development Only)

If you see this error in development:
- Install Python 3.9 or higher from [python.org](https://www.python.org/)
- Restart the app

### Can't Find Apple TV

- Ensure your computer and Apple TV are on the same network
- Check firewall settings
- Try restarting your Apple TV

### Backend Won't Start

In development, check:
- Python virtual environment exists: `backend/venv/`
- Dependencies are installed: `backend/venv/bin/pip list`
- Port 8000 is available: `lsof -i :8000`

In production, the backend is bundled and should work automatically. If it fails, check the Console.app logs for details.

## Advanced Configuration

### Environment Variables

The `.env.example` files contain sensible defaults. You typically don't need to change anything, but you can customize:

#### Root `.env`
```
VITE_API_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000/ws/control
```

#### Backend `.env`
```
HOST=127.0.0.1
PORT=8000
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

## Support

For issues or questions:
- Check the [README](README.md) for general usage
- Open an issue on GitHub
- Check Console.app for error logs (macOS)

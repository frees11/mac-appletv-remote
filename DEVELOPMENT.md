# Development Guide

## Architecture Overview

### Backend (Python + FastAPI + pyatv)

The backend handles all communication with Apple TV devices using the `pyatv` library.

**Key Components:**

- `app/services/atv_service.py`: Core service managing Apple TV connections
- `app/api/`: REST API endpoints for device management and control
- `app/ws/`: WebSocket endpoint for real-time communication
- `app/models/`: Pydantic models for type safety

**API Flow:**

1. Client scans for devices → `GET /api/devices`
2. User pairs device → `POST /api/devices/{id}/pair`
3. User connects → `POST /api/devices/{id}/connect`
4. Control via WebSocket → `WS /ws/control`

### Frontend (Vue 3 + TypeScript)

The frontend provides a touch-friendly remote control interface.

**Key Components:**

- `src/views/DeviceList.vue`: Device discovery and pairing
- `src/views/RemoteControl.vue`: Main remote control UI
- `src/composables/useWebSocket.ts`: WebSocket connection management
- `src/composables/useApi.ts`: REST API wrapper

**UI Features:**

- Touch/swipe gestures on touchpad
- Haptic feedback (on supported devices)
- Real-time playback info updates
- Connection status indicator

### Electron (Desktop App)

Electron wraps the web app and manages the Python backend process.

**Key Features:**

- Spawns Python backend as child process
- System tray integration
- Global keyboard shortcuts
- Menu bar app behavior

## Development Workflow

### Hot Reload Development

1. Start Vite dev server: `npm run dev`
2. Start Electron: `npm run electron:dev`
3. Changes to Vue files auto-reload
4. Backend changes require restart

### Backend Development

```bash
cd backend
python main.py
```

Access API docs at `http://localhost:8000/docs`

### Testing WebSocket

You can test WebSocket connection manually:

```javascript
const ws = new WebSocket('ws://localhost:8000/ws/control')

ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'command',
    payload: {
      device_id: 'YOUR_DEVICE_ID',
      action: 'play_pause'
    }
  }))
}
```

## Adding New Features

### Adding a New Remote Command

1. Add action to `RemoteAction` type in `src/types/index.ts`
2. Add button in `src/views/RemoteControl.vue`
3. Add handler in `backend/app/services/atv_service.py`

### Adding a New API Endpoint

1. Create endpoint in `backend/app/api/`
2. Add route to `backend/main.py`
3. Create wrapper in `src/composables/useApi.ts`

## Building for Production

### macOS

```bash
npm run electron:build -- --mac
```

### Windows

```bash
npm run electron:build -- --win
```

### Linux

```bash
npm run electron:build -- --linux
```

## Debugging

### Backend Logs

Backend logs are printed to Electron console when running `electron:dev`.

### Frontend Debugging

Open DevTools in Electron:
- Menu → View → Toggle Developer Tools
- Or uncomment `mainWindow.webContents.openDevTools()` in `electron/main.js`

### Network Issues

Check if backend is running:

```bash
curl http://localhost:8000/health
```

## Common Issues

### pyatv not found

```bash
cd backend
pip install -r requirements.txt
```

### Port already in use

Change port in `backend/.env`:

```
PORT=8001
```

And update `electron/main.js`:

```javascript
const BACKEND_PORT = 8001
```

## Code Style

- **Frontend**: Uses Prettier (implicitly via Vite)
- **Backend**: Uses Black (recommended)

```bash
cd backend
pip install black
black .
```

## Testing

### Manual Testing Checklist

- [ ] Device discovery works
- [ ] Pairing flow completes
- [ ] All remote buttons respond
- [ ] WebSocket reconnects on disconnect
- [ ] Now playing info updates
- [ ] Keyboard shortcuts work
- [ ] Tray icon works
- [ ] App quits cleanly

## Resources

- [pyatv Documentation](https://pyatv.dev/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Vue 3 Documentation](https://vuejs.org/)
- [Electron Documentation](https://www.electronjs.org/)

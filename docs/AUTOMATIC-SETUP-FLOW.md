# Automatic Setup Flow

This document explains exactly what happens when you launch ATV Remote for the first time.

## Production Flow (Built .app)

When you double-click `ATV Remote.app`:

### Step 1: App Launch (0-1 second)
```
User: Double-clicks ATV Remote.app
Electron: Starts main process
Console: "App is ready, running automatic setup..."
```

### Step 2: Environment Setup (1-2 seconds)
```
runAutoSetup():
  1. Checks for ~/.Library/Application Support/ATV Remote/.env
     → Not found? Copies from bundled .env.example

  2. Checks for ~/.Library/Application Support/ATV Remote/backend.env
     → Not found? Copies from bundled backend/.env.example

Console: "📝 Creating .env file..."
Console: "📝 Creating backend/.env file..."
Console: "✅ Setup complete"
```

### Step 3: Backend Startup (2-3 seconds)
```
startBackend():
  1. Finds backend binary at:
     Resources/app.asar.unpacked/backend/dist/atv-backend/atv-backend

  2. Spawns process with environment:
     HOST=127.0.0.1
     PORT=8000
     CORS_ORIGINS=*

  3. Backend starts FastAPI server

Console: "Starting backend server..."
Console: "🚀 Starting server on 127.0.0.1:8000"
Console: "[Backend STDOUT] 🚀 Starting Apple TV Remote Backend..."
```

### Step 4: Health Check (3-5 seconds)
```
waitForBackend():
  Attempt 1: GET http://localhost:8000/health → Connection refused
  Attempt 2: GET http://localhost:8000/health → Connection refused
  Attempt 3: GET http://localhost:8000/health → 200 OK ✓

Console: "Health check attempt 1/30..."
Console: "Health check attempt 2/30..."
Console: "Health check attempt 3/30..."
Console: "✅ Backend is ready! { status: 'ok' }"
```

### Step 5: UI Launch (5-6 seconds)
```
createWindow():
  1. Creates BrowserWindow (500x800)
  2. Loads dist/index.html
  3. Shows window when ready

createTray():
  1. Creates menu bar icon
  2. Adds context menu

registerGlobalShortcuts():
  1. Registers Cmd+Shift+R (Mac) or Ctrl+Shift+R (Win/Linux)

Console: "Creating window..."
Console: "Global shortcut Command+Shift+R registered"

User sees: Main window opens with remote control interface
```

### Total Time: ~5-6 seconds from double-click to ready

---

## Development Flow (npm run electron:dev)

When you run `npm run electron:dev`:

### Step 1: Vite Dev Server (0-3 seconds)
```
npm run dev:
  Vite: Starts dev server on http://localhost:5173
  Vite: Builds Vue app

Console: "VITE v5.1.4 ready in 234 ms"
Console: "➜ Local: http://localhost:5173/"
```

### Step 2: Electron Launch (3-4 seconds)
```
electron .:
  Electron: Starts main process

Console: "App is ready, running automatic setup..."
```

### Step 3: Environment Setup (4-5 seconds)
```
runAutoSetup():
  1. Checks for .env in project root
     → Not found? Copies from .env.example

  2. Checks for backend/.env
     → Not found? Copies from backend/.env.example

  3. Checks for backend/venv/
     → Not found? Creates virtual environment

     If venv doesn't exist:
       a. Finds Python (tries python3, then python)
       b. Runs: python3 -m venv backend/venv
       c. Upgrades pip
       d. Runs: pip install -r backend/requirements.txt

       This takes 30-60 seconds on first run!

Console: "🔧 Running automatic setup..."
Console: "📝 Creating .env file..."
Console: "📝 Creating backend/.env file..."
Console: "🐍 Creating Python virtual environment..."
Console: "Creating venv with python3..."
Console: "📦 Installing Python dependencies..."
Console: "✅ Python environment setup complete"
Console: "✅ Setup complete"
```

### Step 4: Backend Startup (5-6 seconds, or 65-66 if venv created)
```
startBackend():
  1. Uses: backend/venv/bin/python3
  2. Runs: backend/main.py
  3. Backend starts with auto-reload enabled

Console: "Starting backend server..."
Console: "isDev: true"
Console: "Dev mode - Python: /path/to/backend/venv/bin/python3"
Console: "Dev mode - Backend: /path/to/backend/main.py"
Console: "[Backend STDOUT] 🚀 Starting Apple TV Remote Backend..."
Console: "[Backend STDOUT] 🚀 Starting server on 127.0.0.1:8000"
Console: "[Backend STDOUT] INFO: Uvicorn running on http://127.0.0.1:8000"
```

### Step 5: Health Check (6-8 seconds)
```
waitForBackend():
  Polls /health endpoint until ready

Console: "Waiting for backend to be ready (max 30 attempts, 1000ms delay)..."
Console: "Health check attempt 1/30..."
Console: "Health check attempt 2/30..."
Console: "✅ Backend is ready! { status: 'ok' }"
```

### Step 6: UI Launch (8-9 seconds)
```
createWindow():
  Loads http://localhost:5173 (Vite dev server)

Console: "Creating window..."
Console: "Global shortcut Command+Shift+R registered"

User sees: Electron window opens with hot-reload enabled
```

### Total Time
- **First run** (creating venv): ~65-70 seconds
- **Subsequent runs** (venv exists): ~8-9 seconds

---

## Error Scenarios

### Python Not Found (Development Only)

```
runAutoSetup():
  Try: which python3 → Not found
  Try: which python → Not found

  Shows dialog:
    Title: "Python Not Found"
    Message: "Python 3.9 or higher is required to run ATV Remote.
              Please install Python from python.org and restart the app."

  app.quit()
```

### Backend Failed to Start

```
waitForBackend():
  Attempt 1-30: All fail with connection refused

  Shows dialog:
    Title: "Backend Failed to Start"
    Message: "The backend server could not be started.
              Please check the console logs for details."

  app.quit()
```

### Port Already in Use

```
[Backend STDERR] ERROR: [Errno 48] Address already in use

Shows dialog (same as above)
app.quit()
```

---

## Visual Timeline

```
Production (First Launch):
0s   ━━━━━ App Launch
1s   ━━━━━ Copy .env files
2s   ━━━━━ Start backend binary
3s   ━━━━━ Health check (attempt 1)
4s   ━━━━━ Health check (attempt 2)
5s   ━━━━━ Health check (attempt 3) ✓
6s   ━━━━━ Show main window ✓
     ══════════════════════════════
     USER CAN START USING THE APP

Development (First Launch):
0s   ━━━━━ Start Vite
3s   ━━━━━ App Launch
4s   ━━━━━ Copy .env files
5s   ━━━━━ Create Python venv
35s  ━━━━━ Install dependencies
65s  ━━━━━ Start backend
67s  ━━━━━ Health check ✓
68s  ━━━━━ Show main window ✓
     ══════════════════════════════
     USER CAN START USING THE APP

Development (Subsequent Launches):
0s   ━━━━━ Start Vite
3s   ━━━━━ App Launch
4s   ━━━━━ Check .env (already exists) ✓
5s   ━━━━━ Check venv (already exists) ✓
6s   ━━━━━ Start backend
8s   ━━━━━ Health check ✓
9s   ━━━━━ Show main window ✓
     ══════════════════════════════
     USER CAN START USING THE APP
```

---

## Optimization Opportunities

### Current Setup Time
- Production: ~5-6 seconds (acceptable)
- Development (first): ~65-70 seconds (one-time, acceptable)
- Development (normal): ~8-9 seconds (acceptable)

### Potential Improvements

1. **Parallel Health Checks**
   - Start checking while backend is still starting
   - Current: Sequential (start → wait → check)
   - Potential: Parallel (start + check simultaneously)
   - Savings: ~1-2 seconds

2. **Faster Python Install**
   - Use `pip install --no-cache-dir` to avoid cache overhead
   - Use `--only-binary :all:` to avoid compilation
   - Savings: ~10-15 seconds on first install

3. **Progress Dialog**
   - Show visual progress during first setup
   - Better UX during 65-second wait
   - No time savings, but better perceived performance

4. **Backend Binary Optimization**
   - Use `--onefile` instead of `--onedir` for PyInstaller
   - Faster startup (no directory scanning)
   - Savings: ~0.5-1 second

All timings are acceptable for a desktop app. The automatic setup provides huge value despite the one-time 65-second wait in development.

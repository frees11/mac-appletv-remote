# Backend Setup for Production Build

The backend needs Python and dependencies to be available when running the built app.

## Current Setup

The app uses **system Python** in production mode. This means:
- Python 3.9+ must be installed on the user's system
- Required Python packages must be available

## For Development

Development uses the virtual environment:
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## For Production (Built App)

### Option 1: System Python (Current)

Users need to:
1. Have Python 3.9+ installed
2. Install dependencies globally:
   ```bash
   pip3 install -r backend/requirements-prod.txt
   ```

**Pros:** Simple, small app size
**Cons:** Users need to install Python

### Option 2: Bundle Python (Recommended for distribution)

Use PyInstaller to create a standalone backend executable:

```bash
# Install PyInstaller
pip install pyinstaller

# Create standalone backend
cd backend
pyinstaller --onefile \
  --name backend-server \
  --hidden-import=uvicorn.logging \
  --hidden-import=uvicorn.loops.auto \
  --hidden-import=uvicorn.protocols.http.auto \
  --hidden-import=pyatv \
  main.py

# This creates: backend/dist/backend-server
```

Then update `electron/main.js`:
```javascript
const backendExecutable = isDev
  ? path.join(__dirname, '../backend/venv/bin/python3')
  : path.join(process.resourcesPath, 'backend-server')
```

**Pros:** No Python installation needed
**Cons:** Larger app size

### Option 3: Ship with Bundled Python

Include a minimal Python runtime with your app.

## Installing System Dependencies (For Users)

### macOS
```bash
# Install Python via Homebrew
brew install python@3.11

# Install backend dependencies
pip3 install fastapi uvicorn pyatv websockets python-dotenv
```

### Windows
Download Python from python.org, then:
```cmd
pip install fastapi uvicorn pyatv websockets python-dotenv
```

### Linux (Ubuntu/Debian)
```bash
sudo apt install python3 python3-pip
pip3 install fastapi uvicorn pyatv websockets python-dotenv
```

## Recommended: Create Installer Script

Create `scripts/install-backend-deps.sh`:
```bash
#!/bin/bash
pip3 install fastapi uvicorn pyatv websockets python-dotenv
echo "Backend dependencies installed!"
```

Include this in your distribution and tell users to run it once.

## Debugging Production Backend

Check Console.app (macOS) for backend logs:
1. Open Console.app
2. Search for "ATV Remote"
3. Look for backend startup logs

Or run the app from terminal:
```bash
/Applications/ATV\ Remote.app/Contents/MacOS/ATV\ Remote
```

This will show all console.log output including backend errors.

## Future: Auto-Install Dependencies

You could add a startup check in electron/main.js:
```javascript
function checkPythonDependencies() {
  const { execSync } = require('child_process')
  try {
    execSync('pip3 show fastapi', { stdio: 'ignore' })
    return true
  } catch {
    return false
  }
}

// Show dialog if dependencies missing
if (!checkPythonDependencies()) {
  dialog.showMessageBox({
    type: 'error',
    title: 'Missing Dependencies',
    message: 'Python dependencies not installed',
    detail: 'Please run: pip3 install -r requirements.txt'
  })
}
```

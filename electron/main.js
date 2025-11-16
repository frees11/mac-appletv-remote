const { app, BrowserWindow, Tray, Menu, globalShortcut, shell, ipcMain } = require('electron')
const path = require('path')
const { spawn, execSync } = require('child_process')
const fs = require('fs')

let mainWindow = null
let tray = null
let backendProcess = null
let screenWindows = {}

const isDev = !app.isPackaged

// Backend server configuration
const BACKEND_PORT = 8000
const BACKEND_URL = `http://localhost:${BACKEND_PORT}`

async function runAutoSetup() {
  console.log('🔧 Running automatic setup...')

  // In production, .env.example files are in the app bundle
  const rootEnvExample = isDev
    ? path.join(__dirname, '../.env.example')
    : path.join(process.resourcesPath, '.env.example')

  const backendEnvExample = isDev
    ? path.join(__dirname, '../backend/.env.example')
    : path.join(process.resourcesPath, 'backend', '.env.example')

  // Create .env files in user's home directory for production (to persist settings)
  // In dev mode, use project directory
  const userDataPath = app.getPath('userData')
  const rootEnv = isDev
    ? path.join(__dirname, '../.env')
    : path.join(userDataPath, '.env')

  const backendEnv = isDev
    ? path.join(__dirname, '../backend/.env')
    : path.join(userDataPath, 'backend.env')

  console.log('Root .env example:', rootEnvExample)
  console.log('Root .env:', rootEnv)
  console.log('Backend .env example:', backendEnvExample)
  console.log('Backend .env:', backendEnv)

  if (!fs.existsSync(rootEnv) && fs.existsSync(rootEnvExample)) {
    console.log('📝 Creating .env file...')
    fs.copyFileSync(rootEnvExample, rootEnv)
  }

  if (!fs.existsSync(backendEnv) && fs.existsSync(backendEnvExample)) {
    console.log('📝 Creating backend/.env file...')
    fs.copyFileSync(backendEnvExample, backendEnv)
  }

  // Check if Python venv exists (only in dev mode)
  if (isDev) {
    const backendDir = path.join(__dirname, '../backend')
    const venvPath = path.join(backendDir, 'venv')
    if (!fs.existsSync(venvPath)) {
      console.log('🐍 Creating Python virtual environment...')

      try {
        // Try to find Python
        let pythonCmd = 'python3'
        try {
          execSync('which python3', { stdio: 'ignore' })
        } catch {
          try {
            execSync('which python', { stdio: 'ignore' })
            pythonCmd = 'python'
          } catch {
            console.error('❌ Python not found. Please install Python 3.9 or higher.')
            const { dialog } = require('electron')
            dialog.showErrorBox(
              'Python Not Found',
              'Python 3.9 or higher is required to run ATV Remote.\n\nPlease install Python from python.org and restart the app.'
            )
            return false
          }
        }

        // Create venv
        console.log(`Creating venv with ${pythonCmd}...`)
        execSync(`${pythonCmd} -m venv "${venvPath}"`, { stdio: 'inherit' })

        // Install requirements
        console.log('📦 Installing Python dependencies...')
        const pipPath = path.join(venvPath, 'bin', 'pip')
        const requirementsPath = path.join(backendDir, 'requirements.txt')

        execSync(`"${pipPath}" install --upgrade pip`, { stdio: 'inherit' })
        execSync(`"${pipPath}" install -r "${requirementsPath}"`, { stdio: 'inherit' })

        console.log('✅ Python environment setup complete')
      } catch (error) {
        console.error('❌ Failed to set up Python environment:', error)
        const { dialog } = require('electron')
        dialog.showErrorBox(
          'Setup Failed',
          'Failed to set up Python environment. Please check the console logs for details.'
        )
        return false
      }
    } else {
      console.log('✅ Python virtual environment already exists')
    }
  }

  console.log('✅ Setup complete')
  return true
}

function startBackend() {
  console.log('Starting backend server...')
  console.log('isDev:', isDev)

  let backendExecutable

  if (isDev) {
    // Development mode - use Python with venv
    const pythonPath = path.join(__dirname, '../backend/venv/bin/python3')
    const backendPath = path.join(__dirname, '../backend/main.py')
    console.log('Dev mode - Python:', pythonPath)
    console.log('Dev mode - Backend:', backendPath)

    backendProcess = spawn(pythonPath, [backendPath], {
      env: {
        ...process.env,
        HOST: '127.0.0.1',
        PORT: BACKEND_PORT.toString(),
        CORS_ORIGINS: 'http://localhost:5173,http://localhost:3000,http://localhost:8000',
        PYTHONUNBUFFERED: '1',
      },
    })
  } else {
    // Production mode - use standalone executable
    const fs = require('fs')

    const possiblePaths = [
      path.join(process.resourcesPath, 'app.asar.unpacked', 'backend', 'dist', 'atv-backend', 'atv-backend'),
      path.join(process.resourcesPath, 'backend', 'dist', 'atv-backend', 'atv-backend'),
      path.join(__dirname, '../backend/dist/atv-backend', 'atv-backend'),
    ]

    console.log('Searching for backend executable in:', possiblePaths)
    console.log('process.resourcesPath:', process.resourcesPath)
    console.log('__dirname:', __dirname)

    for (const p of possiblePaths) {
      console.log(`Checking: ${p}`)
      if (fs.existsSync(p)) {
        backendExecutable = p
        console.log('✅ Found backend at:', p)
        break
      } else {
        console.log(`  Not found: ${p}`)
      }
    }

    if (!backendExecutable) {
      console.error('❌ Backend executable not found!')
      console.error('Searched paths:', possiblePaths)
      console.error('Make sure to run: ./scripts/build-backend.sh before building the app')
      return false
    }

    console.log('Starting backend executable:', backendExecutable)

    backendProcess = spawn(backendExecutable, [], {
      env: {
        ...process.env,
        HOST: '127.0.0.1',
        PORT: BACKEND_PORT.toString(),
        // Allow CORS from Electron app (file:// protocol) and localhost
        CORS_ORIGINS: '*',
      },
    })
  }

  backendProcess.stdout.on('data', (data) => {
    console.log(`[Backend STDOUT] ${data.toString().trim()}`)
  })

  backendProcess.stderr.on('data', (data) => {
    console.error(`[Backend STDERR] ${data.toString().trim()}`)
  })

  backendProcess.on('close', (code) => {
    console.log(`Backend process exited with code ${code}`)
    backendProcess = null
  })

  backendProcess.on('error', (error) => {
    console.error('Failed to start backend:', error)
    backendProcess = null
  })

  console.log('✅ Backend process spawned (waiting for health check...)')
  return true
}

async function waitForBackend(maxAttempts = 30, delayMs = 1000) {
  console.log(`Waiting for backend to be ready (max ${maxAttempts} attempts, ${delayMs}ms delay)...`)

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      console.log(`Health check attempt ${attempt}/${maxAttempts}...`)

      const response = await fetch(`${BACKEND_URL}/health`, {
        method: 'GET',
        headers: { 'Accept': 'application/json' },
      })

      if (response.ok) {
        const data = await response.json()
        console.log('✅ Backend is ready!', data)
        return true
      } else {
        console.log(`Backend responded with status ${response.status}`)
      }
    } catch (error) {
      console.log(`Attempt ${attempt} failed:`, error.message)
    }

    // Wait before next attempt
    await new Promise(resolve => setTimeout(resolve, delayMs))
  }

  console.error('❌ Backend failed to start after', maxAttempts, 'attempts')
  return false
}

function stopBackend() {
  if (backendProcess) {
    console.log('Stopping backend...')
    backendProcess.kill()
    backendProcess = null
  }
}

function createWindow() {
  // Get the icon path based on environment
  const iconPath = isDev
    ? path.join(__dirname, '../build/icon.png')
    : path.join(process.resourcesPath, 'icon.png')

  mainWindow = new BrowserWindow({
    width: 500,
    height: 800,
    minWidth: 200, // umožní zmenšit na třetinu
    minHeight: 300, // umožní zmenšit na třetinu
    icon: iconPath,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
    show: false,
    backgroundColor: '#1c1c1e',
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 12, y: 12 },
  })

  // Load the app
  if (isDev) {
    mainWindow.loadURL('http://localhost:5173')
    // mainWindow.webContents.openDevTools()
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'))
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show()
  })

  mainWindow.on('closed', () => {
    mainWindow = null
  })

  // Handle external links
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })
}

function createTray() {
  const fs = require('fs')

  // Get the tray icon path based on platform and environment
  let iconPath

  if (process.platform === 'darwin') {
    // macOS uses Template icon for better integration with dark/light mode
    iconPath = isDev
      ? path.join(__dirname, '../build/tray-iconTemplate.png')
      : path.join(process.resourcesPath, 'tray-iconTemplate.png')
  } else {
    // Windows and Linux use regular icon
    iconPath = isDev
      ? path.join(__dirname, '../build/tray-icon.png')
      : path.join(process.resourcesPath, 'tray-icon.png')
  }

  // Skip tray if icon doesn't exist
  if (!fs.existsSync(iconPath)) {
    console.log('Tray icon not found, skipping tray creation')
    return
  }

  tray = new Tray(iconPath)

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Show ATV Remote',
      click: () => {
        if (mainWindow) {
          mainWindow.show()
          mainWindow.focus()
        } else {
          createWindow()
        }
      },
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        app.quit()
      },
    },
  ])

  tray.setToolTip('ATV Remote')
  tray.setContextMenu(contextMenu)

  tray.on('click', () => {
    if (mainWindow) {
      if (mainWindow.isVisible()) {
        mainWindow.hide()
      } else {
        mainWindow.show()
        mainWindow.focus()
      }
    } else {
      createWindow()
    }
  })
}

function registerGlobalShortcuts() {
  // Register Cmd+Shift+R (Mac) or Ctrl+Shift+R (Win/Linux)
  const shortcut = process.platform === 'darwin' ? 'Command+Shift+R' : 'Ctrl+Shift+R'

  const registered = globalShortcut.register(shortcut, () => {
    if (mainWindow) {
      if (mainWindow.isVisible()) {
        mainWindow.hide()
      } else {
        mainWindow.show()
        mainWindow.focus()
      }
    } else {
      createWindow()
    }
  })

  if (registered) {
    console.log(`Global shortcut ${shortcut} registered`)
  } else {
    console.log(`Failed to register global shortcut ${shortcut}`)
  }
}

function createScreenWindow(deviceId, deviceName) {
  console.log(`Creating screen window for device ${deviceId}`)

  // If window already exists for this device, focus it
  if (screenWindows[deviceId] && !screenWindows[deviceId].isDestroyed()) {
    screenWindows[deviceId].focus()
    return
  }

  const iconPath = isDev
    ? path.join(__dirname, '../build/icon.png')
    : path.join(process.resourcesPath, 'icon.png')

  const screenWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    icon: iconPath,
    title: `${deviceName} - Screen`,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
    backgroundColor: '#000000',
  })

  // Load the screen view
  if (isDev) {
    screenWindow.loadURL(`http://localhost:5173/#/screen/${deviceId}?name=${encodeURIComponent(deviceName)}`)
  } else {
    const indexPath = path.join(__dirname, '../dist/index.html')
    screenWindow.loadFile(indexPath, {
      hash: `/screen/${deviceId}?name=${encodeURIComponent(deviceName)}`,
    })
  }

  screenWindow.on('closed', () => {
    delete screenWindows[deviceId]
  })

  screenWindows[deviceId] = screenWindow
}

// IPC handler for opening screen window
ipcMain.handle('open-screen-window', (event, deviceId, deviceName) => {
  createScreenWindow(deviceId, deviceName)
})

// App lifecycle
app.whenReady().then(async () => {
  console.log('App is ready, running automatic setup...')

  // Run automatic setup
  const setupSuccess = await runAutoSetup()

  if (!setupSuccess) {
    console.error('Setup failed')
    app.quit()
    return
  }

  console.log('Starting backend...')
  const backendStarted = startBackend()

  if (!backendStarted) {
    console.error('Failed to start backend process')
    app.quit()
    return
  }

  // Wait for backend to be ready
  const backendReady = await waitForBackend()

  if (!backendReady) {
    console.error('Backend failed to become ready')
    console.error('The app will not function correctly without the backend')
    // Show error dialog
    const { dialog } = require('electron')
    dialog.showErrorBox(
      'Backend Failed to Start',
      'The backend server could not be started. Please check the console logs for details.'
    )
    app.quit()
    return
  }

  console.log('Creating window...')
  createWindow()
  createTray()
  registerGlobalShortcuts()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

app.on('window-all-closed', () => {
  // Keep app running in tray on macOS
  if (process.platform !== 'darwin') {
    // app.quit()
  }
})

app.on('before-quit', () => {
  globalShortcut.unregisterAll()
  stopBackend()
})

app.on('will-quit', () => {
  stopBackend()
})

// Handle app errors
process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error)
})

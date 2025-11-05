# Apple TV Screen Streaming Setup Guide

This guide explains how to set up real-time screen streaming from your Apple TV to the remote control application.

## Overview

The screen streaming feature allows you to see what's currently displayed on your Apple TV directly in the remote control interface. This uses the `pymobiledevice3` library to capture screenshots from your Apple TV and stream them via WebSocket.

## Features

- Real-time screen preview (2-5 fps)
- Works wirelessly over WiFi
- Automatic frame optimization
- Low latency streaming
- Toggle on/off as needed

## Prerequisites

### 1. Apple TV Requirements

- **Apple TV 4K (2nd gen or later)** or **Apple TV HD (4th gen)**
- **tvOS 15.0 or later**
- **Developer Mode enabled** (required for screenshot access)

### 2. System Requirements

- Python 3.8 or later
- macOS, Linux, or Windows
- Apple TV and computer on the **same WiFi network**

## Setup Instructions

### Step 1: Install Dependencies

Install the new Python dependencies:

```bash
cd backend
pip install -r requirements.txt
```

This will install:
- `pymobiledevice3` (for Apple TV communication)
- `pillow` (for image processing)

### Step 2: Enable Developer Mode on Apple TV

1. On your Apple TV, go to **Settings**
2. Navigate to **Remotes and Devices**
3. Select **Remote App and Devices**
4. Enable **Developer Mode** (if available)

**Alternative method:**
1. Connect Apple TV to Xcode on Mac
2. Go to **Window → Devices and Simulators**
3. Select your Apple TV
4. Enable Developer Mode from device options

### Step 3: Pair Apple TV for Screenshot Access

You need to pair your Apple TV with the application for screenshot access:

#### Option A: Using Python CLI (Recommended)

```bash
# Start the pairing process
python3 -m pymobiledevice3 remote pair
```

Follow the on-screen instructions. A pairing code will appear on your Apple TV - enter it when prompted.

#### Option B: Using the Application API

Once the backend is running, you can use the API endpoint:

```bash
# Start backend
cd backend
python main.py

# In another terminal, trigger pairing
curl -X POST http://localhost:8000/api/screenshot/{device_id}/pair
```

Replace `{device_id}` with your Apple TV's identifier (visible in the device list).

### Step 4: Start the Tunnel Daemon

The tunnel daemon enables wireless communication with your Apple TV:

```bash
# Requires sudo/admin privileges
sudo python3 -m pymobiledevice3 remote tunneld
```

**Keep this running in a separate terminal window.**

**Note:** You may need to enter your system password.

### Step 5: Start the Application

```bash
# Backend
cd backend
python main.py

# Frontend (in another terminal)
npm run dev
```

## Using Screen Streaming

1. Connect to your Apple TV using the device list
2. Open the remote control interface
3. Click the **"📺 Show Screen"** button
4. The Apple TV screen will appear above the remote controls
5. Click **"📺 Hide Screen"** to disable streaming

## Troubleshooting

### "pymobiledevice3 is not installed"

**Solution:** Install dependencies:
```bash
cd backend
pip install pymobiledevice3 pillow
```

### "Failed to start tunnel daemon"

**Cause:** Insufficient permissions

**Solution:** Run tunnel daemon with sudo:
```bash
sudo python3 -m pymobiledevice3 remote tunneld
```

### "Failed to capture screenshot"

**Possible causes:**
1. Apple TV not paired
2. Tunnel daemon not running
3. Developer Mode not enabled
4. Apple TV not on same network

**Solution:**
1. Verify Developer Mode is enabled on Apple TV
2. Complete pairing process (Step 3)
3. Ensure tunnel daemon is running (Step 4)
4. Check both devices are on same WiFi network

### "Black screen" or "No image"

**Cause:** DRM-protected content (Netflix, Apple TV+, etc.)

**Explanation:** Due to digital rights management, streaming apps with DRM protection will show a black screen. This is an Apple/industry limitation, not an application bug.

**Works with:**
- Home screen and menus
- Settings
- Photos app
- Games
- Non-DRM protected apps

**Does NOT work with:**
- Netflix
- Apple TV+
- Disney+
- Amazon Prime Video
- Other DRM-protected streaming services

### Low frame rate

**Expected behavior:** The streaming is snapshot-based, not true video. Expected frame rate is 2-5 fps.

**To adjust:** Modify the `interval` parameter in `RemoteControl.vue`:

```typescript
send({
  type: 'start_screenshot_stream',
  payload: {
    device_id: props.id,
    interval: 0.1,  // Lower = faster (0.1 = ~10fps, but higher CPU usage)
  },
})
```

**Warning:** Lower intervals increase CPU and network usage.

## Technical Details

### Architecture

1. **Backend (`screenshot_service.py`):**
   - Uses `pymobiledevice3` to communicate with Apple TV
   - Captures screenshots via Developer DVT services
   - Compresses images to JPEG (quality: 85%)
   - Resizes to max 800px width for performance
   - Converts to base64 for transmission

2. **WebSocket Communication:**
   - Real-time bidirectional messaging
   - Message types:
     - `start_screenshot_stream` - Client requests stream
     - `screenshot_frame` - Server sends frame
     - `stop_screenshot_stream` - Client stops stream
     - `screenshot_error` - Error notification

3. **Frontend (`ScreenStream.vue`):**
   - Displays base64-encoded JPEG images
   - Shows FPS counter
   - Automatic frame updates
   - Smooth loading states

### Performance Considerations

- **Network:** ~50-200 KB per frame (depends on content complexity)
- **CPU:** Moderate (image compression + encoding)
- **Memory:** Low (~10-20 MB per stream)
- **Latency:** ~200-500ms (network + processing)

### Security Notes

- Tunnel daemon requires **sudo** (system-level USB/network access)
- Pairing uses **secure encryption** (same as Xcode)
- Screenshots stored **temporarily** in `/tmp` (auto-deleted)
- No persistent storage of screen content

## Advanced Configuration

### Custom Screenshot Quality

Edit `backend/app/services/screenshot_service.py`:

```python
async def capture_screenshot(self, device_id: str, quality: int = 85):
    # Change quality (1-100, higher = better quality but larger file size)
```

### Custom Image Size

```python
max_width = 800  # Change to desired max width (pixels)
```

### Streaming Interval

Frontend (`RemoteControl.vue`):

```typescript
interval: 0.2,  // 200ms between frames (~5 fps)
```

## Limitations

1. **Snapshot-based:** Not true video streaming (2-5 fps)
2. **DRM content:** Protected content shows black screen
3. **Developer Mode:** Must be enabled on Apple TV
4. **Same network:** Both devices must be on same WiFi
5. **Sudo required:** Tunnel daemon needs admin privileges
6. **macOS/Linux recommended:** Best compatibility on Unix-like systems

## Future Improvements

Potential enhancements:
- [ ] Automatic pairing UI workflow
- [ ] Background tunnel daemon service
- [ ] Higher frame rates (experimental)
- [ ] H.264 video streaming (requires AirPlay reverse engineering)
- [ ] Multi-device streaming
- [ ] Screenshot recording/saving

## Support

For issues or questions:
1. Check [pymobiledevice3 documentation](https://github.com/doronz88/pymobiledevice3)
2. Verify Apple TV Developer Mode is enabled
3. Check console logs for errors
4. Ensure tunnel daemon is running

## License

This feature uses the open-source `pymobiledevice3` library under MIT License.

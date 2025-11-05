# Apple TV Screen Streaming - Quick Reference

## What is it?

Real-time screen preview from your Apple TV displayed directly in the remote control app.

## How to use

1. **Enable Developer Mode** on Apple TV (Settings → Remotes and Devices)
2. **Install dependencies:**
   ```bash
   cd backend
   pip install pymobiledevice3 pillow
   ```
3. **Pair your Apple TV:**
   ```bash
   python3 -m pymobiledevice3 remote pair
   ```
4. **Start tunnel daemon** (in background):
   ```bash
   sudo python3 -m pymobiledevice3 remote tunneld
   ```
5. **Launch the app** and click **"📺 Show Screen"** button

## What works

✅ Home screen and menus
✅ Settings
✅ Photos
✅ Games
✅ Non-DRM apps

## What doesn't work

❌ Netflix
❌ Apple TV+
❌ Disney+
❌ Amazon Prime
❌ Other DRM-protected streaming services

(Shows black screen due to Apple's DRM protection - this is expected)

## Performance

- **Frame rate:** 2-5 fps (snapshot-based, not video)
- **Latency:** ~200-500ms
- **Quality:** Good (compressed JPEG)
- **Network usage:** ~50-200 KB/frame

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "pymobiledevice3 not installed" | Run `pip install pymobiledevice3` |
| "Failed to capture screenshot" | Enable Developer Mode + pair device + start tunnel |
| "Black screen" | Expected for DRM content (use for menus/settings only) |
| "No image" | Ensure tunnel daemon is running with sudo |

## Full Documentation

See **[SCREEN-STREAMING-SETUP.md](SCREEN-STREAMING-SETUP.md)** for complete setup guide.

## Technical Stack

- **Library:** pymobiledevice3 (Apple device communication)
- **Protocol:** Remote Service Discovery (RSD) over WiFi
- **Transport:** WebSocket (real-time streaming)
- **Format:** JPEG base64 (optimized for size)
- **Resolution:** Auto-scaled to 800px max width

## Architecture

```
Apple TV (Developer Mode)
    ↓ WiFi
RSD Tunnel Daemon (pymobiledevice3)
    ↓
Screenshot Service (Python)
    ↓ WebSocket
Frontend (Vue 3)
    ↓
User sees screen preview
```

## Limitations

1. Requires Developer Mode on Apple TV
2. Snapshot-based (not true video streaming)
3. DRM content shows black screen
4. Requires sudo for tunnel daemon
5. Same WiFi network required
6. 2-5 fps frame rate

## Future Improvements

- [ ] Automatic tunnel daemon management
- [ ] One-click pairing from UI
- [ ] Higher frame rates
- [ ] Video encoding (H.264 streaming)
- [ ] Screenshot recording/saving

---

**Questions?** Check the full setup guide: [SCREEN-STREAMING-SETUP.md](SCREEN-STREAMING-SETUP.md)

import asyncio
import base64
import io
import os
import subprocess
import time
from pathlib import Path
from typing import Optional, Dict
from PIL import Image


class ScreenshotService:

    def __init__(self):
        self.tunnel_process: Optional[subprocess.Popen] = None
        self.paired_devices: Dict[str, bool] = {}
        self.streaming_tasks: Dict[str, asyncio.Task] = {}
        self.screenshot_cache: Dict[str, str] = {}

    async def check_pymobiledevice3_available(self) -> bool:
        try:
            result = subprocess.run(
                ["python3", "-m", "pymobiledevice3", "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception as e:
            print(f"❌ pymobiledevice3 not available: {e}")
            return False

    async def pair_device(self, device_id: str) -> Dict[str, any]:
        try:
            print(f"🔐 Attempting to pair Apple TV device: {device_id}")

            result = subprocess.run(
                ["python3", "-m", "pymobiledevice3", "remote", "pair"],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                self.paired_devices[device_id] = True
                print(f"✅ Successfully paired device: {device_id}")
                return {
                    "success": True,
                    "message": "Device paired successfully. You may need to confirm on your Apple TV."
                }
            else:
                print(f"❌ Pairing failed: {result.stderr}")
                return {
                    "success": False,
                    "error": f"Pairing failed: {result.stderr}"
                }

        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "error": "Pairing timeout. Make sure Apple TV is on the same network and in Developer Mode."
            }
        except Exception as e:
            print(f"❌ Pairing error: {e}")
            return {
                "success": False,
                "error": str(e)
            }

    async def start_tunnel_daemon(self) -> bool:
        if self.tunnel_process and self.tunnel_process.poll() is None:
            print("ℹ️  Tunnel daemon already running")
            return True

        try:
            print("🚀 Starting RSD tunnel daemon...")

            self.tunnel_process = subprocess.Popen(
                ["sudo", "python3", "-m", "pymobiledevice3", "remote", "tunneld"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            await asyncio.sleep(2)

            if self.tunnel_process.poll() is None:
                print("✅ Tunnel daemon started successfully")
                return True
            else:
                print(f"❌ Tunnel daemon failed to start")
                return False

        except Exception as e:
            print(f"❌ Failed to start tunnel daemon: {e}")
            return False

    async def capture_screenshot(self, device_id: str, quality: int = 85) -> Optional[str]:
        try:
            temp_path = Path(f"/tmp/atv_screenshot_{device_id}_{int(time.time())}.png")

            result = subprocess.run(
                [
                    "python3", "-m", "pymobiledevice3",
                    "developer", "dvt", "screenshot",
                    str(temp_path),
                    "--tunnel", device_id
                ],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0 and temp_path.exists():
                img = Image.open(temp_path)

                max_width = 800
                if img.width > max_width:
                    ratio = max_width / img.width
                    new_size = (max_width, int(img.height * ratio))
                    img = img.resize(new_size, Image.Resampling.LANCZOS)

                buffer = io.BytesIO()
                img.save(buffer, format="JPEG", quality=quality, optimize=True)
                buffer.seek(0)

                base64_image = base64.b64encode(buffer.read()).decode('utf-8')

                temp_path.unlink()

                self.screenshot_cache[device_id] = base64_image

                return base64_image
            else:
                print(f"❌ Screenshot capture failed: {result.stderr}")
                return None

        except subprocess.TimeoutExpired:
            print(f"⚠️  Screenshot capture timeout for device {device_id}")
            return None
        except Exception as e:
            print(f"❌ Screenshot error: {e}")
            return None
        finally:
            if temp_path.exists():
                temp_path.unlink()

    async def start_streaming(self, device_id: str, callback, interval: float = 0.2):
        print(f"📹 Starting screenshot streaming for device: {device_id} (interval: {interval}s)")

        while True:
            try:
                screenshot = await self.capture_screenshot(device_id)

                if screenshot:
                    await callback({
                        "type": "screenshot_frame",
                        "payload": {
                            "device_id": device_id,
                            "image": screenshot,
                            "timestamp": time.time()
                        }
                    })
                else:
                    await callback({
                        "type": "screenshot_error",
                        "payload": {
                            "device_id": device_id,
                            "message": "Failed to capture screenshot"
                        }
                    })

                await asyncio.sleep(interval)

            except asyncio.CancelledError:
                print(f"🛑 Streaming cancelled for device: {device_id}")
                break
            except Exception as e:
                print(f"❌ Streaming error: {e}")
                await asyncio.sleep(interval)

    def stop_streaming(self, device_id: str):
        if device_id in self.streaming_tasks:
            task = self.streaming_tasks[device_id]
            task.cancel()
            del self.streaming_tasks[device_id]
            print(f"🛑 Stopped streaming for device: {device_id}")

    async def cleanup(self):
        for device_id in list(self.streaming_tasks.keys()):
            self.stop_streaming(device_id)

        if self.tunnel_process and self.tunnel_process.poll() is None:
            print("🛑 Stopping tunnel daemon...")
            self.tunnel_process.terminate()
            try:
                self.tunnel_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.tunnel_process.kill()


screenshot_service = ScreenshotService()

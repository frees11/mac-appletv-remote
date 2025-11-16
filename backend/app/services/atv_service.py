import asyncio
import json
import os
from typing import Dict, List, Optional, Any
from pathlib import Path

import pyatv
from pyatv import connect
from pyatv.const import Protocol
from pyatv.interface import AppleTV

from app.models import DeviceInfo, PlaybackInfo


class ATVService:
    """Service for managing Apple TV connections and control"""

    def __init__(self):
        self.connections: Dict[str, AppleTV] = {}

        # Store credentials in user's home directory to persist across restarts
        # Use ~/Library/Application Support/atv-remote on macOS
        # Use ~/.config/atv-remote on Linux
        # Use %APPDATA%/atv-remote on Windows
        if os.name == 'nt':  # Windows
            config_dir = Path(os.getenv('APPDATA')) / 'atv-remote'
        elif os.name == 'posix':  # macOS and Linux
            if os.uname().sysname == 'Darwin':  # macOS
                config_dir = Path.home() / 'Library' / 'Application Support' / 'atv-remote'
            else:  # Linux
                config_dir = Path.home() / '.config' / 'atv-remote'
        else:
            # Fallback to current directory
            config_dir = Path('.')

        # Create config directory if it doesn't exist
        config_dir.mkdir(parents=True, exist_ok=True)

        self.credentials_file = config_dir / "credentials.json"
        print(f"📁 Using credentials file: {self.credentials_file}")

        # Migrate old credentials if they exist in the current directory
        old_credentials_file = Path("credentials.json")
        if old_credentials_file.exists() and not self.credentials_file.exists():
            try:
                print(f"🔄 Migrating credentials from old location...")
                import shutil
                shutil.copy2(old_credentials_file, self.credentials_file)
                print(f"✅ Credentials migrated successfully")
            except Exception as e:
                print(f"⚠️  Failed to migrate credentials: {e}")

        self.credentials: Dict[str, Dict[str, Any]] = self._load_credentials()
        self.pairing_sessions: Dict[str, Any] = {}  # Store active pairing sessions

    def _load_credentials(self) -> Dict[str, Dict[str, Any]]:
        """Load stored credentials from file"""
        if self.credentials_file.exists():
            try:
                with open(self.credentials_file, "r") as f:
                    creds = json.load(f)
                    print(f"✅ Loaded credentials for {len(creds)} device(s)")
                    return creds
            except Exception as e:
                print(f"❌ Error loading credentials: {e}")
        else:
            print(f"ℹ️  No credentials file found (will be created on first pairing)")
        return {}

    def _save_credentials(self):
        """Save credentials to file"""
        try:
            with open(self.credentials_file, "w") as f:
                json.dump(self.credentials, f, indent=2)
            print(f"💾 Saved credentials to {self.credentials_file}")
        except Exception as e:
            print(f"❌ Error saving credentials: {e}")

    async def scan_devices(self, timeout: int = 5) -> List[DeviceInfo]:
        """Scan for Apple TV devices on the network"""
        devices = []

        try:
            atvs = await pyatv.scan(timeout=timeout, loop=asyncio.get_event_loop())

            for atv in atvs:
                identifier = atv.identifier or str(atv.address)
                is_paired = identifier in self.credentials

                devices.append(DeviceInfo(
                    identifier=identifier,
                    name=atv.name,
                    address=str(atv.address),
                    model=atv.device_info.model.name if atv.device_info else None,
                    os_version=atv.device_info.version if atv.device_info else None,
                    paired=is_paired,
                    available=True,
                ))
        except Exception as e:
            print(f"Error scanning for devices: {e}")

        return devices

    async def pair_device(self, identifier: str, pin: Optional[str] = None) -> Dict[str, Any]:
        """Pair with an Apple TV device"""
        print(f"🔐 Starting pairing for device {identifier}, PIN provided: {pin is not None}")

        try:
            # If PIN is provided, use existing pairing session
            if pin and identifier in self.pairing_sessions:
                print(f"   Using existing pairing session and submitting PIN...")
                pairing = self.pairing_sessions[identifier]

                try:
                    pairing.pin(pin)
                    print(f"   PIN submitted, finishing pairing...")
                    await pairing.finish()

                    # Save credentials
                    if pairing.service and pairing.service.credentials:
                        protocol_name = pairing.service.protocol.name
                        if identifier not in self.credentials:
                            self.credentials[identifier] = {}

                        self.credentials[identifier][protocol_name] = pairing.service.credentials
                        self._save_credentials()
                        print(f"   ✅ Credentials saved")

                    # Clean up session
                    del self.pairing_sessions[identifier]

                    return {
                        "success": True,
                        "protocol": pairing.service.protocol.name,
                        "message": f"Paired successfully"
                    }
                except Exception as e:
                    print(f"   ❌ Failed to complete pairing with PIN: {e}")
                    # Clean up failed session
                    if identifier in self.pairing_sessions:
                        del self.pairing_sessions[identifier]
                    return {"success": False, "error": f"Failed to complete pairing: {str(e)}"}

            # Start new pairing session
            print(f"   Scanning for device...")
            atvs = await pyatv.scan(identifier=identifier, timeout=3, loop=asyncio.get_event_loop())

            if not atvs:
                print(f"   ❌ Device not found during scan")
                return {"success": False, "error": "Device not found"}

            config = atvs[0]
            print(f"   ✅ Found device: {config.name}")

            # Try to pair with available protocols
            for protocol in [Protocol.Companion, Protocol.AirPlay]:
                service = config.get_service(protocol)
                if service:
                    print(f"   Trying to pair via {protocol.name}...")
                    try:
                        pairing = await pyatv.pair(config, protocol, loop=asyncio.get_event_loop())
                        print(f"   Starting pairing process...")

                        # Add timeout to pairing.begin() to prevent long waits
                        try:
                            await asyncio.wait_for(pairing.begin(), timeout=10.0)
                            print(f"   Pairing begun successfully")
                        except asyncio.TimeoutError:
                            print(f"   ⚠️  Pairing begin timed out after 10 seconds, continuing anyway...")
                            # Continue even if timeout - the device might still show PIN

                        if pairing.device_provides_pin:
                            # Device will show PIN, store session for later
                            print(f"   Device will show PIN, storing session...")
                            self.pairing_sessions[identifier] = pairing
                            return {
                                "success": False,
                                "needs_pin": True,
                                "message": "Enter PIN shown on Apple TV"
                            }
                        else:
                            # We provide PIN to device
                            pin_code = pairing.pin_code
                            self.pairing_sessions[identifier] = pairing
                            return {
                                "success": False,
                                "provide_pin": True,
                                "pin": pin_code,
                                "message": "Enter this PIN on your Apple TV"
                            }

                        # If we get here without needing PIN, finish immediately
                        await pairing.finish()

                        # Save credentials
                        if pairing.service and pairing.service.credentials:
                            if identifier not in self.credentials:
                                self.credentials[identifier] = {}

                            self.credentials[identifier][protocol.name] = pairing.service.credentials
                            self._save_credentials()

                        return {
                            "success": True,
                            "protocol": protocol.name,
                            "message": f"Paired successfully via {protocol.name}"
                        }

                    except Exception as e:
                        print(f"   ❌ Failed to pair via {protocol.name}: {e}")
                        import traceback
                        traceback.print_exc()
                        continue
                else:
                    print(f"   ⚠️  Protocol {protocol.name} not available on device")

            print(f"   ❌ Failed to pair with any available protocol")
            return {"success": False, "error": "Failed to pair with any protocol"}

        except Exception as e:
            print(f"   ❌ Pairing error: {e}")
            import traceback
            traceback.print_exc()
            return {"success": False, "error": str(e)}

    async def connect_device(self, identifier: str) -> bool:
        """Connect to a paired Apple TV device"""
        if identifier in self.connections:
            return True

        try:
            # Scan for the device (reduced timeout for faster response)
            atvs = await pyatv.scan(identifier=identifier, timeout=3, loop=asyncio.get_event_loop())

            if not atvs:
                return False

            config = atvs[0]

            # Apply stored credentials
            if identifier in self.credentials:
                for protocol_name, creds in self.credentials[identifier].items():
                    try:
                        protocol = Protocol[protocol_name]
                        service = config.get_service(protocol)
                        if service:
                            service.credentials = creds
                    except Exception as e:
                        print(f"Error applying credentials for {protocol_name}: {e}")

            # Connect
            atv = await connect(config, loop=asyncio.get_event_loop())
            self.connections[identifier] = atv

            print(f"✅ Successfully connected to device {identifier}")
            print(f"   Active connections: {list(self.connections.keys())}")

            return True

        except Exception as e:
            print(f"Error connecting to device {identifier}: {e}")
            return False

    async def disconnect_device(self, identifier: str):
        """Disconnect from an Apple TV device"""
        if identifier in self.connections:
            try:
                atv = self.connections[identifier]
                atv.close()
                del self.connections[identifier]
            except Exception as e:
                print(f"Error disconnecting from device {identifier}: {e}")

    async def unpair_device(self, identifier: str) -> Dict[str, Any]:
        """Unpair a device by removing its stored credentials"""
        try:
            # Disconnect if currently connected
            if identifier in self.connections:
                await self.disconnect_device(identifier)

            # Remove credentials
            if identifier in self.credentials:
                del self.credentials[identifier]
                self._save_credentials()
                print(f"✅ Unpaired device {identifier}")
                return {"success": True, "message": "Device unpaired successfully"}
            else:
                return {"success": False, "error": "Device was not paired"}

        except Exception as e:
            print(f"❌ Error unpairing device {identifier}: {e}")
            return {"success": False, "error": str(e)}

    async def send_command(self, identifier: str, action: str, value: Optional[int] = None) -> bool:
        """Send a remote control command to the device"""
        print(f"📤 Sending command '{action}' to device {identifier}")

        if identifier not in self.connections:
            print(f"⚠️  Device not connected, attempting to connect...")
            connected = await self.connect_device(identifier)
            if not connected:
                print(f"❌ Failed to connect to device {identifier}")
                return False

        try:
            atv = self.connections[identifier]
            remote = atv.remote_control

            # Debug: Show available remote control methods
            print(f"   Using remote control for {identifier}")
            print(f"   Remote control type: {type(remote).__name__}")
            print(f"   Available methods: {[m for m in dir(remote) if not m.startswith('_')]}")

            # Map actions to remote control methods
            # Try common command names, fall back to alternatives
            action_map = {
                "up": remote.up,
                "down": remote.down,
                "left": remote.left,
                "right": remote.right,
                "select": remote.select,
                "menu": remote.menu,
                "home": remote.home,
                "play": remote.play,
                "pause": remote.pause,
                "play_pause": remote.play_pause,
                "next": remote.next,
                "previous": remote.previous,
                "volume_up": remote.volume_up,
                "volume_down": remote.volume_down,
                "top_menu": remote.top_menu,
                "tv": remote.home,  # TV button maps to home
            }

            if action in action_map:
                try:
                    command = action_map[action]
                    if callable(command):
                        print(f"   Calling command function: {command}")
                        await command()
                        print(f"✅ Command '{action}' sent successfully")
                        return True
                    else:
                        print(f"❌ Command '{action}' is not callable")
                        return False
                except Exception as cmd_error:
                    # Print full error details
                    print(f"❌ Command '{action}' failed with error: {cmd_error}")
                    print(f"   Error type: {type(cmd_error).__name__}")
                    import traceback
                    traceback.print_exc()

                    # Try alternatives for unsupported commands
                    if "not supported" in str(cmd_error).lower() or "not available" in str(cmd_error).lower():
                        print(f"⚠️  Command '{action}' not supported, trying alternative...")

                        # Alternative commands for unsupported ones
                        if action == "play_pause":
                            try:
                                await remote.play()
                                print(f"✅ Used 'play' as alternative")
                                return True
                            except Exception as alt_error:
                                print(f"❌ Alternative 'play' also failed: {alt_error}")
                        elif action == "menu":
                            try:
                                await remote.top_menu()
                                print(f"✅ Used 'top_menu' as alternative")
                                return True
                            except Exception as alt_error:
                                print(f"❌ Alternative 'top_menu' also failed: {alt_error}")

                    return False

            print(f"❌ Unknown action: {action}")
            return False

        except Exception as e:
            print(f"Error sending command {action} to {identifier}: {e}")
            return False

    async def get_playback_info(self, identifier: str) -> Optional[PlaybackInfo]:
        """Get current playback information from the device"""
        if identifier not in self.connections:
            connected = await self.connect_device(identifier)
            if not connected:
                return None

        try:
            atv = self.connections[identifier]
            playing = await atv.metadata.playing()

            return PlaybackInfo(
                device_id=identifier,
                title=playing.title,
                artist=playing.artist,
                album=playing.album,
                app=playing.app.name if hasattr(playing, 'app') and playing.app else None,
                playback_state=playing.device_state.name.lower() if playing.device_state else None,
                position=playing.position,
                duration=playing.total_time,
                artwork_url=None,  # Would need to fetch artwork separately
            )

        except Exception as e:
            print(f"Error getting playback info from {identifier}: {e}")
            return None

    async def cleanup(self):
        """Cleanup all connections"""
        for identifier in list(self.connections.keys()):
            await self.disconnect_device(identifier)


# Global service instance
atv_service = ATVService()

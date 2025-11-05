import json
import asyncio
from typing import Dict, Set
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.services.atv_service import atv_service
from app.services.screenshot_service import screenshot_service

router = APIRouter()


class ConnectionManager:
    """Manage WebSocket connections"""

    def __init__(self):
        self.active_connections: Set[WebSocket] = set()

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.add(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.discard(websocket)

    async def send_personal_message(self, message: dict, websocket: WebSocket):
        await websocket.send_json(message)

    async def broadcast(self, message: dict):
        """Broadcast message to all connected clients"""
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                pass


manager = ConnectionManager()


@router.websocket("/control")
async def websocket_control(websocket: WebSocket):
    """WebSocket endpoint for real-time control"""
    print("🔌 New WebSocket connection")
    await manager.connect(websocket)

    try:
        while True:
            # Receive message from client
            data = await websocket.receive_text()
            print(f"📨 Received WebSocket message: {data}", flush=True)

            try:
                message = json.loads(data)
                message_type = message.get("type")
                payload = message.get("payload", {})
                print(f"   Type: {message_type}, Payload: {payload}", flush=True)

                if message_type == "command":
                    # Handle remote control command
                    device_id = payload.get("device_id")
                    action = payload.get("action")
                    value = payload.get("value")
                    print(f"   Processing command: device={device_id}, action={action}")

                    if device_id and action:
                        success = await atv_service.send_command(device_id, action, value)

                        await manager.send_personal_message({
                            "type": "command_result",
                            "payload": {
                                "success": success,
                                "action": action,
                            }
                        }, websocket)

                elif message_type == "get_playing":
                    # Get current playback info
                    device_id = payload.get("device_id")

                    if device_id:
                        info = await atv_service.get_playback_info(device_id)

                        await manager.send_personal_message({
                            "type": "playback_info",
                            "payload": info.dict() if info else None
                        }, websocket)

                elif message_type == "start_screenshot_stream":
                    device_id = payload.get("device_id")
                    interval = payload.get("interval", 0.2)

                    if device_id:
                        print(f"📹 Starting screenshot stream for device: {device_id}")

                        async def send_screenshot(message):
                            await manager.send_personal_message(message, websocket)

                        task = asyncio.create_task(
                            screenshot_service.start_streaming(device_id, send_screenshot, interval)
                        )
                        screenshot_service.streaming_tasks[device_id] = task

                        await manager.send_personal_message({
                            "type": "stream_started",
                            "payload": {"device_id": device_id}
                        }, websocket)

                elif message_type == "stop_screenshot_stream":
                    device_id = payload.get("device_id")

                    if device_id:
                        print(f"🛑 Stopping screenshot stream for device: {device_id}")
                        screenshot_service.stop_streaming(device_id)

                        await manager.send_personal_message({
                            "type": "stream_stopped",
                            "payload": {"device_id": device_id}
                        }, websocket)

                elif message_type == "ping":
                    await manager.send_personal_message({
                        "type": "pong",
                        "payload": {}
                    }, websocket)

            except json.JSONDecodeError:
                await manager.send_personal_message({
                    "type": "error",
                    "payload": {"message": "Invalid JSON"}
                }, websocket)

            except Exception as e:
                await manager.send_personal_message({
                    "type": "error",
                    "payload": {"message": str(e)}
                }, websocket)

    except WebSocketDisconnect:
        print("🔌 WebSocket disconnected")
        manager.disconnect(websocket)

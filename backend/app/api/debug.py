from fastapi import APIRouter
from app.services.atv_service import atv_service

router = APIRouter()


@router.get("/debug/connections")
async def debug_connections():
    """Debug endpoint to check active connections"""
    return {
        "active_connections": list(atv_service.connections.keys()),
        "total_connections": len(atv_service.connections),
    }


@router.get("/debug/device/{device_id}/features")
async def debug_device_features(device_id: str):
    """Check what features/commands the device supports"""
    if device_id not in atv_service.connections:
        return {"error": "Device not connected"}

    atv = atv_service.connections[device_id]
    remote = atv.remote_control

    # Test which commands are available
    available_commands = []
    test_commands = [
        "up", "down", "left", "right", "select",
        "menu", "home", "top_menu",
        "play", "pause", "play_pause",
        "next", "previous",
        "volume_up", "volume_down"
    ]

    for cmd in test_commands:
        if hasattr(remote, cmd):
            available_commands.append(cmd)

    return {
        "device_id": device_id,
        "available_commands": available_commands,
        "device_info": {
            "name": atv.device_info.model if atv.device_info else "Unknown",
        }
    }

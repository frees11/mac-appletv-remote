from fastapi import APIRouter, HTTPException

from app.models import ControlCommand, PlaybackInfo
from app.services.atv_service import atv_service

router = APIRouter()


@router.post("/control/command")
async def send_command(command: ControlCommand):
    """Send a control command to an Apple TV device"""
    try:
        success = await atv_service.send_command(
            command.device_id,
            command.action,
            command.value
        )

        if not success:
            raise HTTPException(
                status_code=400,
                detail="Failed to send command. Make sure device is connected."
            )

        return {"success": True, "action": command.action}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/control/{device_id}/playing", response_model=PlaybackInfo)
async def get_playing(device_id: str):
    """Get current playback information from a device"""
    try:
        info = await atv_service.get_playback_info(device_id)

        if not info:
            raise HTTPException(
                status_code=404,
                detail="Could not get playback info. Make sure device is connected."
            )

        return info
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

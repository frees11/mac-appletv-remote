from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

from app.services.screenshot_service import screenshot_service


router = APIRouter()


class ScreenshotResponse(BaseModel):
    success: bool
    image: Optional[str] = None
    error: Optional[str] = None
    message: Optional[str] = None


class PairResponse(BaseModel):
    success: bool
    message: str
    error: Optional[str] = None


@router.post("/{device_id}/pair", response_model=PairResponse)
async def pair_for_screenshots(device_id: str):
    if not await screenshot_service.check_pymobiledevice3_available():
        raise HTTPException(
            status_code=503,
            detail="pymobiledevice3 is not installed. Run: pip install pymobiledevice3"
        )

    result = await screenshot_service.pair_device(device_id)

    if not result.get("success"):
        raise HTTPException(
            status_code=400,
            detail=result.get("error", "Pairing failed")
        )

    return result


@router.get("/{device_id}/capture", response_model=ScreenshotResponse)
async def capture_screenshot(device_id: str, quality: int = 85):
    if not await screenshot_service.check_pymobiledevice3_available():
        raise HTTPException(
            status_code=503,
            detail="pymobiledevice3 is not installed"
        )

    if quality < 1 or quality > 100:
        raise HTTPException(
            status_code=400,
            detail="Quality must be between 1 and 100"
        )

    image = await screenshot_service.capture_screenshot(device_id, quality)

    if image is None:
        raise HTTPException(
            status_code=500,
            detail="Failed to capture screenshot. Make sure device is paired and tunnel is running."
        )

    return {
        "success": True,
        "image": image
    }


@router.get("/{device_id}/cached", response_model=ScreenshotResponse)
async def get_cached_screenshot(device_id: str):
    cached = screenshot_service.screenshot_cache.get(device_id)

    if cached is None:
        raise HTTPException(
            status_code=404,
            detail="No cached screenshot available for this device"
        )

    return {
        "success": True,
        "image": cached
    }


@router.delete("/{device_id}/stream")
async def stop_stream(device_id: str):
    screenshot_service.stop_streaming(device_id)
    return {"success": True, "message": "Streaming stopped"}

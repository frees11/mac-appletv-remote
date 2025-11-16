from typing import List
from fastapi import APIRouter, HTTPException

from app.models import DeviceInfo, PairingRequest
from app.services.atv_service import atv_service

router = APIRouter()


@router.get("/devices", response_model=List[DeviceInfo])
async def list_devices(timeout: int = 5):
    """Scan and list available Apple TV devices"""
    try:
        devices = await atv_service.scan_devices(timeout=timeout)
        return devices
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/devices/{identifier}/pair")
async def pair_device(identifier: str, request: PairingRequest):
    """Pair with an Apple TV device"""
    try:
        result = await atv_service.pair_device(identifier, request.pin)

        if not result.get("success"):
            if result.get("needs_pin") or result.get("provide_pin"):
                return result

            raise HTTPException(
                status_code=400,
                detail=result.get("error", "Pairing failed")
            )

        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/devices/{identifier}/connect")
async def connect_device(identifier: str):
    """Connect to a paired Apple TV device"""
    try:
        success = await atv_service.connect_device(identifier)

        if not success:
            raise HTTPException(
                status_code=400,
                detail="Failed to connect to device. Make sure it's paired."
            )

        return {"success": True, "message": "Connected successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/devices/{identifier}/disconnect")
async def disconnect_device(identifier: str):
    """Disconnect from an Apple TV device"""
    try:
        await atv_service.disconnect_device(identifier)
        return {"success": True, "message": "Disconnected successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/devices/{identifier}/unpair")
async def unpair_device(identifier: str):
    """Unpair an Apple TV device by removing stored credentials"""
    try:
        result = await atv_service.unpair_device(identifier)

        if not result.get("success"):
            raise HTTPException(
                status_code=400,
                detail=result.get("error", "Failed to unpair device")
            )

        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

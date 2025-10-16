from typing import Optional, Dict, Any
from pydantic import BaseModel


class DeviceInfo(BaseModel):
    """Basic device information"""
    identifier: str
    name: str
    address: str
    model: Optional[str] = None
    os_version: Optional[str] = None
    paired: bool = False
    available: bool = True


class Device(BaseModel):
    """Full device representation with credentials"""
    info: DeviceInfo
    credentials: Optional[Dict[str, Any]] = None


class DeviceStatus(BaseModel):
    """Device connection status"""
    identifier: str
    connected: bool
    available: bool
    error: Optional[str] = None


class PairingRequest(BaseModel):
    """Request to pair with a device"""
    identifier: str
    pin: Optional[str] = None

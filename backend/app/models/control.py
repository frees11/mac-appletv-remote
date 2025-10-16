from typing import Optional, Literal
from pydantic import BaseModel


class ControlCommand(BaseModel):
    """Remote control command"""
    device_id: str
    action: Literal[
        "up", "down", "left", "right",
        "select", "menu", "home",
        "play", "pause", "play_pause",
        "next", "previous",
        "volume_up", "volume_down",
        "top_menu", "tv"
    ]
    value: Optional[int] = None  # For volume or other numeric values


class PlaybackInfo(BaseModel):
    """Current playback information"""
    device_id: str
    title: Optional[str] = None
    artist: Optional[str] = None
    album: Optional[str] = None
    app: Optional[str] = None
    playback_state: Optional[str] = None  # playing, paused, stopped
    position: Optional[float] = None
    duration: Optional[float] = None
    artwork_url: Optional[str] = None

export interface Device {
  identifier: string
  name: string
  address: string
  model?: string
  os_version?: string
  paired: boolean
  available: boolean
}

export interface PlaybackInfo {
  device_id: string
  title?: string
  artist?: string
  album?: string
  app?: string
  playback_state?: 'playing' | 'paused' | 'stopped'
  position?: number
  duration?: number
  artwork_url?: string
}

export type RemoteAction =
  | 'up' | 'down' | 'left' | 'right'
  | 'select' | 'menu' | 'home'
  | 'play' | 'pause' | 'play_pause' | 'stop'
  | 'next' | 'previous'
  | 'volume_up' | 'volume_down' | 'mute'
  | 'top_menu' | 'tv' | 'power' | 'power_off'
  | 'control_center'

export interface ControlCommand {
  device_id: string
  action: RemoteAction
  value?: number
}

export interface WSMessage {
  type:
    | 'command'
    | 'get_playing'
    | 'ping'
    | 'pong'
    | 'command_result'
    | 'playback_info'
    | 'error'
    | 'screenshot_frame'
    | 'screenshot_error'
    | 'stream_started'
    | 'stream_stopped'
    | 'start_screenshot_stream'
    | 'stop_screenshot_stream'
  payload: any
}

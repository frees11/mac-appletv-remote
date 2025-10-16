import type { Device } from '@/types'

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000'

export function useApi() {
  const fetchDevices = async (): Promise<Device[]> => {
    const response = await fetch(`${API_BASE}/api/devices`)
    if (!response.ok) throw new Error('Failed to fetch devices')
    return response.json()
  }

  const pairDevice = async (identifier: string, pin?: string) => {
    const response = await fetch(`${API_BASE}/api/devices/${identifier}/pair`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier, pin }),
    })
    if (!response.ok) throw new Error('Failed to pair device')
    return response.json()
  }

  const connectDevice = async (identifier: string) => {
    const response = await fetch(`${API_BASE}/api/devices/${identifier}/connect`, {
      method: 'POST',
    })
    if (!response.ok) throw new Error('Failed to connect to device')
    return response.json()
  }

  const sendCommand = async (deviceId: string, action: string, value?: number) => {
    const response = await fetch(`${API_BASE}/api/control/command`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ device_id: deviceId, action, value }),
    })
    if (!response.ok) throw new Error('Failed to send command')
    return response.json()
  }

  const getPlaybackInfo = async (deviceId: string) => {
    const response = await fetch(`${API_BASE}/api/control/${deviceId}/playing`)
    if (!response.ok) throw new Error('Failed to get playback info')
    return response.json()
  }

  return {
    fetchDevices,
    pairDevice,
    connectDevice,
    sendCommand,
    getPlaybackInfo,
  }
}

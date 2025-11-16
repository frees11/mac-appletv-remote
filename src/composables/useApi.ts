import type { Device } from '@/types'

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000'

// Helper function to add timeout to fetch requests
const fetchWithTimeout = async (url: string, options: RequestInit = {}, timeout = 5000) => {
  const controller = new AbortController()
  const id = setTimeout(() => controller.abort(), timeout)

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    })
    clearTimeout(id)
    return response
  }
  catch (error) {
    clearTimeout(id)
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error('Request timeout - server took too long to respond')
    }
    throw error
  }
}

export function useApi() {
  const fetchDevices = async (): Promise<Device[]> => {
    const response = await fetchWithTimeout(`${API_BASE}/api/devices`, {}, 10000)
    if (!response.ok) throw new Error('Failed to fetch devices')
    return response.json()
  }

  const pairDevice = async (identifier: string, pin?: string) => {
    const response = await fetchWithTimeout(
      `${API_BASE}/api/devices/${identifier}/pair`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, pin }),
      },
      15000, // 15s timeout for pairing
    )
    if (!response.ok) throw new Error('Failed to pair device')
    return response.json()
  }

  const connectDevice = async (identifier: string) => {
    const response = await fetchWithTimeout(
      `${API_BASE}/api/devices/${identifier}/connect`,
      {
        method: 'POST',
      },
      10000,
    )
    if (!response.ok) throw new Error('Failed to connect to device')
    return response.json()
  }

  const sendCommand = async (deviceId: string, action: string, value?: number) => {
    const response = await fetchWithTimeout(
      `${API_BASE}/api/control/command`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_id: deviceId, action, value }),
      },
      3000, // 3s timeout for commands
    )
    if (!response.ok) throw new Error('Failed to send command')
    return response.json()
  }

  const getPlaybackInfo = async (deviceId: string) => {
    const response = await fetchWithTimeout(
      `${API_BASE}/api/control/${deviceId}/playing`,
      {},
      5000,
    )
    if (!response.ok) throw new Error('Failed to get playback info')
    return response.json()
  }

  const unpairDevice = async (identifier: string) => {
    const response = await fetchWithTimeout(
      `${API_BASE}/api/devices/${identifier}/unpair`,
      {
        method: 'POST',
      },
      5000,
    )
    if (!response.ok) throw new Error('Failed to unpair device')
    return response.json()
  }

  return {
    fetchDevices,
    pairDevice,
    connectDevice,
    sendCommand,
    getPlaybackInfo,
    unpairDevice,
  }
}

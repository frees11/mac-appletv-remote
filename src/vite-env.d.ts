/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string
  readonly VITE_WS_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

interface Window {
  electron?: {
    platform: string
    send: (channel: string, data: any) => void
    receive: (channel: string, func: (...args: any[]) => void) => void
    openScreenWindow: (deviceId: string, deviceName: string) => Promise<void>
  }
}

import { ref, onUnmounted } from 'vue'
import type { WSMessage } from '@/types'

export function useWebSocket(url: string) {
  const ws = ref<WebSocket | null>(null)
  const isConnected = ref(false)
  const lastError = ref<string | null>(null)
  const messageHandler = ref<((message: WSMessage) => void) | null>(null)

  const connect = () => {
    try {
      ws.value = new WebSocket(url)

      ws.value.onopen = () => {
        isConnected.value = true
        lastError.value = null
        console.log('WebSocket connected to', url)
      }

      ws.value.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data) as WSMessage
          console.log('WebSocket received:', message)
          if (messageHandler.value) {
            messageHandler.value(message)
          }
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error)
        }
      }

      ws.value.onclose = () => {
        isConnected.value = false
        console.log('WebSocket disconnected')

        // Reconnect after 3 seconds
        setTimeout(() => {
          if (ws.value?.readyState === WebSocket.CLOSED) {
            connect()
          }
        }, 3000)
      }

      ws.value.onerror = (error) => {
        lastError.value = 'WebSocket error occurred'
        console.error('WebSocket error:', error)
      }
    } catch (error) {
      lastError.value = error instanceof Error ? error.message : 'Connection failed'
      console.error('Failed to connect:', error)
    }
  }

  const disconnect = () => {
    if (ws.value) {
      ws.value.close()
      ws.value = null
    }
  }

  const send = (message: WSMessage) => {
    console.log('WebSocket send attempt:', message, 'Connected:', isConnected.value)
    if (ws.value && isConnected.value) {
      const jsonStr = JSON.stringify(message)
      console.log('Sending:', jsonStr)
      ws.value.send(jsonStr)
    } else {
      console.warn('WebSocket not connected, cannot send message. State:', ws.value?.readyState)
    }
  }

  const onMessage = (handler: (message: WSMessage) => void) => {
    messageHandler.value = handler
  }

  onUnmounted(() => {
    disconnect()
  })

  return {
    ws,
    isConnected,
    lastError,
    connect,
    disconnect,
    send,
    onMessage,
  }
}

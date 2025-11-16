<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useWebSocket } from '@/composables/useWebSocket'
import { useApi } from '@/composables/useApi'
import type { RemoteAction, PlaybackInfo, Device } from '@/types'

const props = defineProps<{
  id: string
}>()

const router = useRouter()
const api = useApi()
const WS_URL = import.meta.env.VITE_WS_URL || 'ws://localhost:8000/ws/control'
const { isConnected, connect, disconnect, send, onMessage } = useWebSocket(WS_URL)

const playbackInfo = ref<PlaybackInfo | null>(null)
const deviceName = ref<string>('')
const deviceAddress = ref<string>('')
const menuPressStart = ref<number | null>(null)
const LONG_PRESS_DURATION = 600
const isElectron = ref(typeof window !== 'undefined' && (window as any).electron)
const remoteRef = ref<HTMLElement | null>(null)

// Calculate initial scale immediately
const calculateScale = () => {
  const padding = 16 * 2 // 1rem on each side = 32px total
  const safetyMargin = 32 // Additional safety margin (double)

  const availableWidth = window.innerWidth - padding - safetyMargin
  const availableHeight = window.innerHeight - padding - safetyMargin

  const baseWidth = 380
  // Get actual height if available, otherwise use approximate height
  const baseHeight = remoteRef.value?.scrollHeight || 850

  const scaleX = availableWidth / baseWidth
  const scaleY = availableHeight / baseHeight

  // Use the smaller scale to ensure everything fits (contain behavior)
  const calculatedScale = Math.min(scaleX, scaleY)

  return Math.min(0.95, Math.max(0.3, calculatedScale))
}

const scale = ref(calculateScale())

const updateScale = () => {
  scale.value = calculateScale()
}

const sendCommand = (action: RemoteAction) => {
  console.log('Sending command:', action, 'to device:', props.id)

  send({
    type: 'command',
    payload: {
      device_id: props.id,
      action,
    },
  })

  if ('vibrate' in navigator) {
    navigator.vibrate(10)
  }
}

const handleMenuPress = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()
  menuPressStart.value = Date.now()
}

const handleMenuRelease = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()
  if (menuPressStart.value) {
    const pressDuration = Date.now() - menuPressStart.value

    if (pressDuration >= LONG_PRESS_DURATION) {
      sendCommand('home')
    } else {
      sendCommand('menu')
    }

    menuPressStart.value = null
  }
}

const handleMenuCancel = () => {
  menuPressStart.value = null
}

const handleTouchpadClick = (e: MouseEvent) => {
  const target = e.currentTarget as HTMLElement
  const rect = target.getBoundingClientRect()

  const centerX = rect.width / 2
  const centerY = rect.height / 2
  const clickX = e.clientX - rect.left - centerX
  const clickY = e.clientY - rect.top - centerY

  const distance = Math.sqrt(clickX * clickX + clickY * clickY)
  const radius = rect.width / 2

  if (distance < radius * 0.5) {
    sendCommand('select')
    return
  }

  const angle = Math.atan2(clickY, clickX) * (180 / Math.PI)

  if (angle >= -45 && angle < 45) {
    sendCommand('right')
  } else if (angle >= 45 && angle < 135) {
    sendCommand('down')
  } else if (angle >= -135 && angle < -45) {
    sendCommand('up')
  } else {
    sendCommand('left')
  }
}

const fetchPlaybackInfo = () => {
  send({
    type: 'get_playing',
    payload: { device_id: props.id },
  })
}

const openScreenInWindow = () => {
  if (isElectron.value) {
    (window as any).electron.openScreenWindow(props.id, deviceName.value || 'Apple TV')
  }
}

const goBack = () => {
  router.push('/')
}

const handleKeyDown = (e: KeyboardEvent) => {
  if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Enter', ' '].includes(e.key)) {
    e.preventDefault()
  }

  switch (e.key) {
    case 'ArrowUp':
      sendCommand('up')
      break
    case 'ArrowDown':
      sendCommand('down')
      break
    case 'ArrowLeft':
      sendCommand('left')
      break
    case 'ArrowRight':
      sendCommand('right')
      break
    case 'Enter':
    case ' ':
      sendCommand('select')
      break
    case 'Escape':
      sendCommand('menu')
      break
    case 'h':
    case 'H':
      sendCommand('home')
      break
    case 'm':
    case 'M':
      sendCommand('menu')
      break
    case 'p':
    case 'P':
      sendCommand('play_pause')
      break
  }
}

let lastWidth = window.innerWidth
let lastHeight = window.innerHeight

const handleResize = () => {
  const currentWidth = window.innerWidth
  const currentHeight = window.innerHeight
  if (currentWidth !== lastWidth || currentHeight !== lastHeight) {
    updateScale()
    lastWidth = currentWidth
    lastHeight = currentHeight
  }
}

onMounted(async () => {
  connect()

  // Initial scale calculation
  updateScale()

  // Ensure scale is applied after DOM is ready
  await nextTick()
  updateScale()

  // Additional update after a short delay to ensure everything is rendered
  setTimeout(() => updateScale(), 50)

  // Try to load device info from sessionStorage first (instant display)
  try {
    const cachedDevice = sessionStorage.getItem(`device_${props.id}`)
    if (cachedDevice) {
      const device = JSON.parse(cachedDevice) as Device
      deviceName.value = device.name
      deviceAddress.value = device.address
      console.log('Loaded device info from cache:', device)
    }
  } catch (e) {
    console.error('Failed to load cached device info:', e)
  }

  // Load device information from API in background (for updates/fallback)
  try {
    const devices = await api.fetchDevices()
    const device = devices.find((d: Device) => d.identifier === props.id)
    if (device) {
      deviceName.value = device.name
      deviceAddress.value = device.address
      console.log('Updated device info from API:', device)
    }
  } catch (e) {
    console.error('Failed to load device info from API:', e)
  }

  window.addEventListener('keydown', handleKeyDown)
  window.addEventListener('resize', handleResize)

  onMessage((message) => {
    console.log('Received WebSocket message:', message)

    if (message.type === 'playback_info') {
      playbackInfo.value = message.payload
    } else if (message.type === 'command_result') {
      console.log('Command result:', message.payload)
      if (!message.payload.success) {
        console.error('Command failed:', message.payload)
      }
    }
  })

  const interval = setInterval(fetchPlaybackInfo, 5000)
  fetchPlaybackInfo()

  onUnmounted(() => {
    clearInterval(interval)
  })
})

onUnmounted(() => {
  disconnect()
  window.removeEventListener('keydown', handleKeyDown)
  window.removeEventListener('resize', handleResize)
})
</script>

<template>
  <div class="wrapper">
    <div class="remote-wrapper" :style="{ width: `${380 * scale}px` }">
      <div ref="remoteRef" class="remote-control w-[380px] px-6 pt-6 pb-12 flex flex-col bg-gradient-to-br from-[#e6e6e6] to-[#d0d0d0] rounded-[2rem]" :style="{ '--scale': scale }">
          <!-- Header -->
          <div class="mb-4">
            <div class="flex justify-between items-center mb-2">
              <button
                @click="goBack"
                class="px-4 py-2 bg-black/8 rounded-lg text-[#1d1d1f] text-sm font-medium transition-colors hover:bg-black/12 flex items-center justify-center cursor-pointer select-none"
              >
                ← Back
              </button>
              <div class="flex items-center gap-2 text-apple-gray-400 text-xs font-medium">
                <div
                  :class="[
                    'w-1.5 h-1.5 rounded-full transition-colors',
                    isConnected ? 'bg-green-500' : 'bg-red-500'
                  ]"
                ></div>
                {{ isConnected ? 'Connected' : 'Disconnected' }}
              </div>
            </div>

            <!-- Device Name -->
            <div class="text-center mt-3 mb-3">
              <h1 class="text-xl font-bold text-[#1d1d1f]">{{ deviceName || 'Apple TV' }}</h1>
              <p v-if="deviceAddress" class="text-xs text-apple-gray-400 mt-1">{{ deviceAddress }}</p>
            </div>

            <!-- Screen Stream Toggle -->
            <div v-if="isElectron" class="flex justify-center mt-2">
              <button
                @click="openScreenInWindow"
                class="px-4 py-2 rounded-lg text-xs font-medium transition-all bg-white/60 text-[#1d1d1f] border border-black/10 hover:bg-white/80"
              >
                📺 Open Screen View
              </button>
            </div>
          </div>

          <!-- Now Playing Info -->
          <div
            v-if="playbackInfo?.title"
            class="bg-white/60 backdrop-blur-[10px] rounded-2xl p-4 mb-4 border border-black/6"
          >
            <div class="flex justify-between items-center gap-4">
              <div class="flex-1 min-w-0">
                <h3 class="text-[0.9375rem] font-semibold text-[#1d1d1f] mb-1 truncate">
                  {{ playbackInfo.title }}
                </h3>
                <p v-if="playbackInfo.artist" class="text-[0.8125rem] text-apple-gray-400 truncate">
                  {{ playbackInfo.artist }}
                </p>
                <p v-if="playbackInfo.app" class="text-[0.6875rem] text-apple-gray-400 mt-0.5">
                  {{ playbackInfo.app }}
                </p>
              </div>
              <div v-if="playbackInfo.playback_state" class="text-2xl text-[#1d1d1f]">
                {{ playbackInfo.playback_state === 'playing' ? '▶' : '⏸' }}
              </div>
            </div>
          </div>

          <!-- Remote Control -->
          <div class="flex-1 flex flex-col gap-4 items-center">
            <!-- Power Button -->
            <div class="w-full flex justify-end -mb-2">
              <button
                @click="sendCommand('power')"
                class="w-8 h-8 bg-white/85 border border-black/8 rounded-full text-[#1d1d1f] transition-all hover:bg-white/95 hover:scale-105 active:scale-95 active:bg-white flex items-center justify-center p-0"
              >
                <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M12 2v10M15.5 6.5a7 7 0 1 1-7 0"/>
                </svg>
              </button>
            </div>

            <!-- Touchpad -->
            <div
              class="w-60 h-60 max-sm:w-50 max-sm:h-50 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full flex items-center justify-center cursor-pointer select-none shadow-[inset_0_2px_8px_rgba(0,0,0,0.4),0_4px_12px_rgba(0,0,0,0.2)] transition-all hover:scale-[1.02] active:scale-[0.98] active:shadow-[inset_0_2px_12px_rgba(0,0,0,0.5),0_2px_8px_rgba(0,0,0,0.2)] my-4 relative"
              @click="handleTouchpadClick"
            >
              <!-- Visual indicators for click zones -->
              <div class="absolute inset-0 rounded-full pointer-events-none">
                <!-- Center select area -->
                <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[50%] h-[50%] rounded-full border border-white/5"></div>

                <!-- Direction arrows -->
                <!-- Up arrow -->
                <div class="absolute top-[3%] left-1/2 -translate-x-1/2">
                  <svg class="w-6 h-6 text-white/40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M5 12l7-7 7 7"/>
                  </svg>
                </div>

                <!-- Down arrow -->
                <div class="absolute bottom-[3%] left-1/2 -translate-x-1/2">
                  <svg class="w-6 h-6 text-white/40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M19 12l-7 7-7-7"/>
                  </svg>
                </div>

                <!-- Left arrow -->
                <div class="absolute left-[3%] top-1/2 -translate-y-1/2">
                  <svg class="w-6 h-6 text-white/40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M12 19l-7-7 7-7"/>
                  </svg>
                </div>

                <!-- Right arrow -->
                <div class="absolute right-[3%] top-1/2 -translate-y-1/2">
                  <svg class="w-6 h-6 text-white/40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M12 5l7 7-7 7"/>
                  </svg>
                </div>
              </div>
              <div class="w-[180px] h-[180px] max-sm:w-[150px] max-sm:h-[150px] border-2 border-white/8 rounded-full pointer-events-none"></div>
            </div>

            <!-- Back and TV Buttons -->
            <div class="flex gap-4 justify-center w-full max-w-60 max-sm:max-w-50">
              <button
                @mousedown="handleMenuPress"
                @mouseup="handleMenuRelease"
                @mouseleave="handleMenuCancel"
                @touchstart="handleMenuPress"
                @touchend="handleMenuRelease"
                @touchcancel="handleMenuCancel"
                class="w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center"
              >
                <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                  <path d="M15 18l-6-6 6-6"/>
                </svg>
              </button>
              <button
                @click="sendCommand('tv')"
                class="w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center"
              >
                <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="2" y="7" width="20" height="13" rx="2"/>
                  <path d="M17 2l-5 5-5-5"/>
                </svg>
              </button>
            </div>

            <!-- Play/Pause and Volume Up -->
            <div class="flex gap-4 justify-center w-full max-w-60 max-sm:max-w-50">
              <button
                @click="sendCommand('play_pause')"
                class="w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center"
              >
                <svg class="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M6 5v14l8-7z"/>
                  <rect x="16" y="5" width="2" height="14" rx="1"/>
                  <rect x="20" y="5" width="2" height="14" rx="1"/>
                </svg>
              </button>
              <button
                @click="sendCommand('volume_up')"
                class="w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-t-[35px] rounded-b-lg text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center"
              >
                <span class="text-[2rem] font-light leading-none">+</span>
              </button>
            </div>

            <!-- Mute and Volume Down -->
            <div class="flex gap-4 justify-center w-full max-w-60 max-sm:max-w-50 -mt-2">
              <button
                @click="sendCommand('mute')"
                class="w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center"
              >
                <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M11 5L6 9H2v6h4l5 4V5zM23 9l-6 6M17 9l6 6"/>
                </svg>
              </button>
              <button
                @click="sendCommand('volume_down')"
                class="w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-t-lg rounded-b-[35px] text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center"
              >
                <span class="text-[2rem] font-light leading-none">−</span>
              </button>
            </div>
          </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.wrapper {
  width: 100vw;
  height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
  overflow: hidden;
  padding: 1rem;
}

.remote-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  transition: width 0.2s ease;
}

.remote-control {
  transform: scale(var(--scale));
  transform-origin: center center;
  transition: transform 0.2s ease;
}
</style>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick, watch } from 'vue'
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
const tvPressStart = ref<number | null>(null)
const playPausePressStart = ref<number | null>(null)
const powerPressStart = ref<number | null>(null)
const volumeUpInterval = ref<number | null>(null)
const volumeDownInterval = ref<number | null>(null)
const LONG_PRESS_DURATION = 600
const VOLUME_REPEAT_INTERVAL = 100

const menuPressProgress = ref(0)
const tvPressProgress = ref(0)
const playPausePressProgress = ref(0)
const powerPressProgress = ref(0)

let menuAnimationFrame: number | null = null
let tvAnimationFrame: number | null = null
let playPauseAnimationFrame: number | null = null
let powerAnimationFrame: number | null = null
const isElectron = ref(typeof window !== 'undefined' && (window as any).electron)
const remoteRef = ref<HTMLElement | null>(null)
const wrapperRef = ref<HTMLElement | null>(null)
const touchpadPressedDirection = ref<string | null>(null)

// Store unscaled natural height
const naturalHeight = ref(0)

// Calculate scale based on window dimensions
const calculateScale = () => {
  const horizontalPadding = 16 * 2 // 1rem on each side = 32px total
  const topPadding = 48 // 3rem top padding
  const bottomPadding = 0 // No bottom padding
  const topMargin = 60 // Further reduced top margin
  const safetyMargin = 2 // Almost no safety margin

  const availableWidth = window.innerWidth - horizontalPadding - safetyMargin
  const availableHeight = window.innerHeight - topPadding - bottomPadding - topMargin - safetyMargin

  const baseWidth = 380
  // Fallback: estimate height without "Now Playing" block (~750px)
  const baseHeight = naturalHeight.value > 0 ? naturalHeight.value : 750

  const scaleX = availableWidth / baseWidth
  const scaleY = availableHeight / baseHeight

  // Use the smaller scale to ensure everything fits
  const calculatedScale = Math.min(scaleX, scaleY)
  const finalScale = Math.min(0.95, Math.max(0.3, calculatedScale))

  const scaledWidth = baseWidth * finalScale
  const scaledHeight = baseHeight * finalScale

  console.log('Scale calc:',
    `window=${window.innerWidth}x${window.innerHeight}`,
    `avail=${Math.round(availableWidth)}x${Math.round(availableHeight)}`,
    `base=${baseWidth}x${baseHeight}`,
    `scaleX=${scaleX.toFixed(2)}`,
    `scaleY=${scaleY.toFixed(2)}`,
    `final=${finalScale.toFixed(2)}`,
    `fits=${scaledWidth <= availableWidth && scaledHeight <= availableHeight ? 'YES' : 'NO'}`
  )

  return finalScale
}

// Initialize with a safe default scale
const scale = ref(0.7)

const updateNaturalHeight = () => {
  if (!wrapperRef.value || !remoteRef.value) return

  // Save current scale and temporarily set to 1 for accurate measurement
  const currentScale = scale.value
  const needsReset = Math.abs(currentScale - 1) > 0.01

  if (needsReset) {
    // Temporarily set to 1 to get true height
    scale.value = 1
  }

  // Wait for DOM update if we changed scale
  const measure = () => {
    if (!remoteRef.value) {
      console.warn('measure: no remoteRef!')
      return
    }

    const scrollHeight = remoteRef.value.scrollHeight
    const offsetHeight = remoteRef.value.offsetHeight

    // Use the larger value
    const measuredHeight = Math.max(scrollHeight, offsetHeight)

    console.log('Natural height measured:',
      `scroll=${scrollHeight}px`,
      `offset=${offsetHeight}px`,
      `measured=${measuredHeight}px`,
      `wasScaled=${needsReset}`,
      `previous=${naturalHeight.value}px`,
      `hasPlayback=${!!playbackInfo.value?.title}`
    )

    // Only update if we got a valid measurement
    if (measuredHeight > 0) {
      naturalHeight.value = measuredHeight
    } else {
      console.warn('Invalid height measurement, keeping previous value:', naturalHeight.value)
    }

    // Restore scale if we changed it
    if (needsReset) {
      scale.value = currentScale
    }

    // Recalculate with new natural height
    updateScale()
  }

  if (needsReset) {
    // Need to wait for DOM update after scale change
    nextTick(measure)
  } else {
    // Can measure immediately
    measure()
  }
}

const updateScale = () => {
  const newScale = calculateScale()

  if (Math.abs(newScale - scale.value) > 0.01) {
    console.log('Scale changed:', scale.value.toFixed(2), '->', newScale.toFixed(2))
  }

  scale.value = newScale
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

const animateMenuProgress = () => {
  if (menuPressStart.value) {
    const elapsed = Date.now() - menuPressStart.value
    menuPressProgress.value = Math.min(100, (elapsed / LONG_PRESS_DURATION) * 100)

    if (menuPressProgress.value < 100) {
      menuAnimationFrame = requestAnimationFrame(animateMenuProgress)
    }
  }
}

const animateTvProgress = () => {
  if (tvPressStart.value) {
    const elapsed = Date.now() - tvPressStart.value
    tvPressProgress.value = Math.min(100, (elapsed / LONG_PRESS_DURATION) * 100)

    if (tvPressProgress.value < 100) {
      tvAnimationFrame = requestAnimationFrame(animateTvProgress)
    }
  }
}

const animatePlayPauseProgress = () => {
  if (playPausePressStart.value) {
    const elapsed = Date.now() - playPausePressStart.value
    playPausePressProgress.value = Math.min(100, (elapsed / LONG_PRESS_DURATION) * 100)

    if (playPausePressProgress.value < 100) {
      playPauseAnimationFrame = requestAnimationFrame(animatePlayPauseProgress)
    }
  }
}

const animatePowerProgress = () => {
  if (powerPressStart.value) {
    const elapsed = Date.now() - powerPressStart.value
    powerPressProgress.value = Math.min(100, (elapsed / LONG_PRESS_DURATION) * 100)

    if (powerPressProgress.value < 100) {
      powerAnimationFrame = requestAnimationFrame(animatePowerProgress)
    }
  }
}

const handleMenuPress = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()
  menuPressStart.value = Date.now()
  menuPressProgress.value = 0
  menuAnimationFrame = requestAnimationFrame(animateMenuProgress)
}

const handleMenuRelease = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  if (menuAnimationFrame) {
    cancelAnimationFrame(menuAnimationFrame)
    menuAnimationFrame = null
  }

  if (menuPressStart.value) {
    const pressDuration = Date.now() - menuPressStart.value

    if (pressDuration >= LONG_PRESS_DURATION) {
      sendCommand('home')
    } else {
      sendCommand('menu')
    }

    menuPressStart.value = null
    menuPressProgress.value = 0
  }
}

const handleMenuCancel = () => {
  menuPressStart.value = null
  menuPressProgress.value = 0

  if (menuAnimationFrame) {
    cancelAnimationFrame(menuAnimationFrame)
    menuAnimationFrame = null
  }
}

const handleTvPress = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()
  tvPressStart.value = Date.now()
  tvPressProgress.value = 0
  tvAnimationFrame = requestAnimationFrame(animateTvProgress)
}

const handleTvRelease = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  if (tvAnimationFrame) {
    cancelAnimationFrame(tvAnimationFrame)
    tvAnimationFrame = null
  }

  if (tvPressStart.value) {
    const pressDuration = Date.now() - tvPressStart.value

    if (pressDuration >= LONG_PRESS_DURATION) {
      sendCommand('control_center')
    } else {
      sendCommand('tv')
    }

    tvPressStart.value = null
    tvPressProgress.value = 0
  }
}

const handleTvCancel = () => {
  tvPressStart.value = null
  tvPressProgress.value = 0

  if (tvAnimationFrame) {
    cancelAnimationFrame(tvAnimationFrame)
    tvAnimationFrame = null
  }
}

const handlePlayPausePress = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()
  playPausePressStart.value = Date.now()
  playPausePressProgress.value = 0
  playPauseAnimationFrame = requestAnimationFrame(animatePlayPauseProgress)
}

const handlePlayPauseRelease = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  if (playPauseAnimationFrame) {
    cancelAnimationFrame(playPauseAnimationFrame)
    playPauseAnimationFrame = null
  }

  if (playPausePressStart.value) {
    const pressDuration = Date.now() - playPausePressStart.value

    if (pressDuration >= LONG_PRESS_DURATION) {
      sendCommand('stop')
    } else {
      sendCommand('play_pause')
    }

    playPausePressStart.value = null
    playPausePressProgress.value = 0
  }
}

const handlePlayPauseCancel = () => {
  playPausePressStart.value = null
  playPausePressProgress.value = 0

  if (playPauseAnimationFrame) {
    cancelAnimationFrame(playPauseAnimationFrame)
    playPauseAnimationFrame = null
  }
}

const handlePowerPress = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()
  powerPressStart.value = Date.now()
  powerPressProgress.value = 0
  powerAnimationFrame = requestAnimationFrame(animatePowerProgress)
}

const handlePowerRelease = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  if (powerAnimationFrame) {
    cancelAnimationFrame(powerAnimationFrame)
    powerAnimationFrame = null
  }

  if (powerPressStart.value) {
    const pressDuration = Date.now() - powerPressStart.value

    if (pressDuration >= LONG_PRESS_DURATION) {
      sendCommand('power_off')
    } else {
      sendCommand('power')
    }

    powerPressStart.value = null
    powerPressProgress.value = 0
  }
}

const handlePowerCancel = () => {
  powerPressStart.value = null
  powerPressProgress.value = 0

  if (powerAnimationFrame) {
    cancelAnimationFrame(powerAnimationFrame)
    powerAnimationFrame = null
  }
}

const handleVolumeUpStart = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  sendCommand('volume_up')

  volumeUpInterval.value = window.setInterval(() => {
    sendCommand('volume_up')
  }, VOLUME_REPEAT_INTERVAL)
}

const handleVolumeUpEnd = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  if (volumeUpInterval.value !== null) {
    clearInterval(volumeUpInterval.value)
    volumeUpInterval.value = null
  }
}

const handleVolumeDownStart = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  sendCommand('volume_down')

  volumeDownInterval.value = window.setInterval(() => {
    sendCommand('volume_down')
  }, VOLUME_REPEAT_INTERVAL)
}

const handleVolumeDownEnd = (e: MouseEvent | TouchEvent) => {
  e.preventDefault()

  if (volumeDownInterval.value !== null) {
    clearInterval(volumeDownInterval.value)
    volumeDownInterval.value = null
  }
}

const setPressedDirection = (e: MouseEvent | TouchEvent) => {
  const target = e.currentTarget as HTMLElement
  const rect = target.getBoundingClientRect()

  let clientX: number
  let clientY: number

  if (e instanceof TouchEvent && e.touches.length > 0) {
    clientX = e.touches[0].clientX
    clientY = e.touches[0].clientY
  } else if (e instanceof MouseEvent) {
    clientX = e.clientX
    clientY = e.clientY
  } else {
    return
  }

  const x = clientX - rect.left
  const y = clientY - rect.top
  const cx = rect.width / 2
  const cy = rect.height / 2
  const dx = x - cx
  const dy = y - cy

  // Determine direction based on which offset is greater
  if (Math.abs(dx) > Math.abs(dy)) {
    touchpadPressedDirection.value = dx < 0 ? 'pressed-left' : 'pressed-right'
  } else {
    touchpadPressedDirection.value = dy < 0 ? 'pressed-top' : 'pressed-bottom'
  }

  console.log('Pressed direction:', touchpadPressedDirection.value, { dx, dy, x, y, cx, cy })
}

const clearPressedDirection = () => {
  console.log('Clearing pressed direction')
  touchpadPressedDirection.value = null
}

let animationClearTimeout: ReturnType<typeof setTimeout> | null = null

const handleTouchpadPress = (e: MouseEvent | TouchEvent) => {
  if (e instanceof MouseEvent && e.button !== 0) return // Only left mouse button

  setPressedDirection(e)

  // Clear any existing timeout
  if (animationClearTimeout) {
    clearTimeout(animationClearTimeout)
  }

  // Auto-clear animation after 200ms
  animationClearTimeout = setTimeout(() => {
    clearPressedDirection()
  }, 200)
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
let resizeTimeout: ReturnType<typeof setTimeout> | null = null

const handleResize = () => {
  const currentWidth = window.innerWidth
  const currentHeight = window.innerHeight

  // Only process if window dimensions actually changed
  if (currentWidth !== lastWidth || currentHeight !== lastHeight) {
    lastWidth = currentWidth
    lastHeight = currentHeight

    // Debounce resize handling
    if (resizeTimeout) {
      clearTimeout(resizeTimeout)
    }

    resizeTimeout = setTimeout(() => {
      console.log('Window resized to:', currentWidth, 'x', currentHeight)
      updateScale()
    }, 100)
  }
}

// Store observers and intervals outside onMounted
let resizeObserver: ResizeObserver | null = null
let playbackInterval: ReturnType<typeof setInterval> | null = null

onMounted(async () => {
  connect()

  // Wait for DOM to be fully ready
  await nextTick()

  console.log('Component mounted')

  // Set up ResizeObserver to watch for content changes (not scale changes)
  let lastObservedHeight = 0
  if (remoteRef.value) {
    resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        if (entry.target === remoteRef.value) {
          // Get unscaled height by dividing observed height by current scale
          const observedHeight = remoteRef.value!.scrollHeight
          const unscaledHeight = Math.abs(scale.value - 1) < 0.01
            ? observedHeight
            : observedHeight / scale.value

          // Only trigger if unscaled height changed significantly (more than 10px)
          if (Math.abs(unscaledHeight - lastObservedHeight) > 10) {
            console.log('Content height changed:', lastObservedHeight, '->', Math.round(unscaledHeight))
            lastObservedHeight = unscaledHeight
            updateNaturalHeight()
          }
        }
      }
    })
    resizeObserver.observe(remoteRef.value)
  }

  // Initial measurement and scale calculation
  // Wait for full render before first measurement
  await nextTick()
  await nextTick() // Extra tick for safety

  // First measurement
  updateNaturalHeight()

  // Backup measurements to ensure we got the right height
  requestAnimationFrame(() => {
    updateNaturalHeight()
  })

  setTimeout(() => {
    updateNaturalHeight()
  }, 50)

  setTimeout(() => {
    updateNaturalHeight()
  }, 200)

  // Watch for playbackInfo changes which can affect height
  // Only remeasure when playbackInfo appears or disappears (not on every update)
  watch(() => playbackInfo.value?.title, (newTitle, oldTitle) => {
    // Only remeasure if the presence of playbackInfo changed
    const wasShown = !!oldTitle
    const isShown = !!newTitle

    if (wasShown !== isShown) {
      console.log('playbackInfo visibility changed:', { wasShown, isShown })
      nextTick(() => {
        updateNaturalHeight()
      })
    }
  })

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

  playbackInterval = setInterval(fetchPlaybackInfo, 5000)
  fetchPlaybackInfo()
})

onUnmounted(() => {
  disconnect()
  window.removeEventListener('keydown', handleKeyDown)
  window.removeEventListener('resize', handleResize)

  // Clean up ResizeObserver
  if (resizeObserver) {
    resizeObserver.disconnect()
    resizeObserver = null
  }

  // Clean up resize timeout
  if (resizeTimeout) {
    clearTimeout(resizeTimeout)
    resizeTimeout = null
  }

  // Clean up progress animations
  if (menuAnimationFrame) cancelAnimationFrame(menuAnimationFrame)
  if (tvAnimationFrame) cancelAnimationFrame(tvAnimationFrame)
  if (playPauseAnimationFrame) cancelAnimationFrame(playPauseAnimationFrame)
  if (powerAnimationFrame) cancelAnimationFrame(powerAnimationFrame)

  // Clean up playback interval
  if (playbackInterval) {
    clearInterval(playbackInterval)
    playbackInterval = null
  }
})
</script>

<template>
  <div class="wrapper">
    <div
      ref="wrapperRef"
      class="remote-wrapper"
    >
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
                @mousedown="handlePowerPress"
                @mouseup="handlePowerRelease"
                @mouseleave="handlePowerCancel"
                @touchstart="handlePowerPress"
                @touchend="handlePowerRelease"
                @touchcancel="handlePowerCancel"
                class="relative w-8 h-8 bg-white/85 border border-black/8 rounded-full text-[#1d1d1f] transition-all hover:bg-white/95 hover:scale-105 active:scale-95 active:bg-white flex items-center justify-center p-0 overflow-visible"
              >
                <!-- Progress Ring -->
                <svg
                  class="absolute -inset-[2px] w-[36px] h-[36px] pointer-events-none"
                  style="transform: rotate(-90deg)"
                >
                  <circle
                    cx="18"
                    cy="18"
                    r="16"
                    fill="none"
                    :stroke="powerPressProgress > 0 ? 'rgba(29, 29, 31, 0.6)' : 'transparent'"
                    stroke-width="2"
                    stroke-linecap="round"
                    :stroke-dasharray="100.5"
                    :stroke-dashoffset="100.5 - (powerPressProgress / 100) * 100.5"
                    :style="{
                      transition: powerPressProgress > 0 ? 'none' : 'stroke 0.2s ease',
                      filter: powerPressProgress > 0 ? 'drop-shadow(0 0 4px rgba(29, 29, 31, 0.4))' : 'none'
                    }"
                  />
                </svg>

                <svg class="w-4 h-4 relative z-10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M12 2v10M15.5 6.5a7 7 0 1 1-7 0"/>
                </svg>
              </button>
            </div>

            <!-- Touchpad -->
            <div class="touchpad-perspective">
              <div
                @click="handleTouchpadClick"
                @mousedown="handleTouchpadPress"
                @mouseup="clearPressedDirection"
                @mouseleave="clearPressedDirection"
                @touchstart="handleTouchpadPress"
                @touchend="clearPressedDirection"
                @touchcancel="clearPressedDirection"
                class="touchpad w-60 h-60 max-sm:w-50 max-sm:h-50 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full flex items-center justify-center cursor-pointer select-none shadow-[inset_0_2px_8px_rgba(0,0,0,0.4),0_4px_12px_rgba(0,0,0,0.2)] my-4 relative"
                :class="{
                  'pressed-left': touchpadPressedDirection === 'pressed-left',
                  'pressed-right': touchpadPressedDirection === 'pressed-right',
                  'pressed-top': touchpadPressedDirection === 'pressed-top',
                  'pressed-bottom': touchpadPressedDirection === 'pressed-bottom'
                }"
              >
                <!-- Visual indicators for click zones -->
                <div class="absolute inset-0 rounded-full pointer-events-none">
                  <!-- Center select area -->
                  <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[50%] h-[50%] rounded-full border border-white/5"></div>

                  <!-- Direction arrows -->
                  <!-- Up arrow -->
                  <div class="absolute top-[3%] left-1/2 -translate-x-1/2">
                    <svg class="w-6 h-6 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                      <path d="M5 12l7-7 7 7"/>
                    </svg>
                  </div>

                  <!-- Down arrow -->
                  <div class="absolute bottom-[3%] left-1/2 -translate-x-1/2">
                    <svg class="w-6 h-6 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                      <path d="M19 12l-7 7-7-7"/>
                    </svg>
                  </div>

                  <!-- Left arrow -->
                  <div class="absolute left-[3%] top-1/2 -translate-y-1/2">
                    <svg class="w-6 h-6 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                      <path d="M12 19l-7-7 7-7"/>
                    </svg>
                  </div>

                  <!-- Right arrow -->
                  <div class="absolute right-[3%] top-1/2 -translate-y-1/2">
                    <svg class="w-6 h-6 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                      <path d="M12 5l7 7-7 7"/>
                    </svg>
                  </div>
                </div>
              </div>
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
                class="relative w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center overflow-visible"
              >
                <!-- Progress Ring -->
                <svg
                  class="absolute -inset-[2px] w-[74px] h-[74px] pointer-events-none"
                  style="transform: rotate(-90deg)"
                >
                  <circle
                    cx="37"
                    cy="37"
                    r="35"
                    fill="none"
                    :stroke="menuPressProgress > 0 ? 'rgba(255, 255, 255, 0.8)' : 'transparent'"
                    stroke-width="3"
                    stroke-linecap="round"
                    :stroke-dasharray="219.8"
                    :stroke-dashoffset="219.8 - (menuPressProgress / 100) * 219.8"
                    :style="{
                      transition: menuPressProgress > 0 ? 'none' : 'stroke 0.2s ease',
                      filter: menuPressProgress > 0 ? 'drop-shadow(0 0 4px rgba(255, 255, 255, 0.6))' : 'none'
                    }"
                  />
                </svg>

                <svg class="w-6 h-6 relative z-10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                  <path d="M15 18l-6-6 6-6"/>
                </svg>
              </button>
              <button
                @mousedown="handleTvPress"
                @mouseup="handleTvRelease"
                @mouseleave="handleTvCancel"
                @touchstart="handleTvPress"
                @touchend="handleTvRelease"
                @touchcancel="handleTvCancel"
                class="relative w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center overflow-visible"
              >
                <!-- Progress Ring -->
                <svg
                  class="absolute -inset-[2px] w-[74px] h-[74px] pointer-events-none"
                  style="transform: rotate(-90deg)"
                >
                  <circle
                    cx="37"
                    cy="37"
                    r="35"
                    fill="none"
                    :stroke="tvPressProgress > 0 ? 'rgba(255, 255, 255, 0.8)' : 'transparent'"
                    stroke-width="3"
                    stroke-linecap="round"
                    :stroke-dasharray="219.8"
                    :stroke-dashoffset="219.8 - (tvPressProgress / 100) * 219.8"
                    :style="{
                      transition: tvPressProgress > 0 ? 'none' : 'stroke 0.2s ease',
                      filter: tvPressProgress > 0 ? 'drop-shadow(0 0 4px rgba(255, 255, 255, 0.6))' : 'none'
                    }"
                  />
                </svg>

                <svg class="w-6 h-6 relative z-10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="2" y="7" width="20" height="13" rx="2"/>
                  <path d="M17 2l-5 5-5-5"/>
                </svg>
              </button>
            </div>

            <!-- Play/Pause and Volume Up -->
            <div class="flex gap-4 justify-center w-full max-w-60 max-sm:max-w-50">
              <button
                @mousedown="handlePlayPausePress"
                @mouseup="handlePlayPauseRelease"
                @mouseleave="handlePlayPauseCancel"
                @touchstart="handlePlayPausePress"
                @touchend="handlePlayPauseRelease"
                @touchcancel="handlePlayPauseCancel"
                class="relative w-[70px] h-[70px] max-sm:w-15 max-sm:h-15 bg-gradient-radial from-apple-gray-700 to-apple-gray-900 rounded-full text-apple-gray-50 transition-all shadow-[inset_0_1px_4px_rgba(0,0,0,0.3),0_3px_8px_rgba(0,0,0,0.2)] hover:scale-105 active:scale-95 active:shadow-[inset_0_1px_6px_rgba(0,0,0,0.4),0_2px_6px_rgba(0,0,0,0.2)] flex items-center justify-center overflow-visible"
              >
                <!-- Progress Ring -->
                <svg
                  class="absolute -inset-[2px] w-[74px] h-[74px] pointer-events-none"
                  style="transform: rotate(-90deg)"
                >
                  <circle
                    cx="37"
                    cy="37"
                    r="35"
                    fill="none"
                    :stroke="playPausePressProgress > 0 ? 'rgba(255, 255, 255, 0.8)' : 'transparent'"
                    stroke-width="3"
                    stroke-linecap="round"
                    :stroke-dasharray="219.8"
                    :stroke-dashoffset="219.8 - (playPausePressProgress / 100) * 219.8"
                    :style="{
                      transition: playPausePressProgress > 0 ? 'none' : 'stroke 0.2s ease',
                      filter: playPausePressProgress > 0 ? 'drop-shadow(0 0 4px rgba(255, 255, 255, 0.6))' : 'none'
                    }"
                  />
                </svg>

                <svg class="w-6 h-6 relative z-10" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M6 5v14l8-7z"/>
                  <rect x="16" y="5" width="2" height="14" rx="1"/>
                  <rect x="20" y="5" width="2" height="14" rx="1"/>
                </svg>
              </button>
              <button
                @mousedown="handleVolumeUpStart"
                @mouseup="handleVolumeUpEnd"
                @mouseleave="handleVolumeUpEnd"
                @touchstart="handleVolumeUpStart"
                @touchend="handleVolumeUpEnd"
                @touchcancel="handleVolumeUpEnd"
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
                @mousedown="handleVolumeDownStart"
                @mouseup="handleVolumeDownEnd"
                @mouseleave="handleVolumeDownEnd"
                @touchstart="handleVolumeDownStart"
                @touchend="handleVolumeDownEnd"
                @touchcancel="handleVolumeDownEnd"
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
  overflow: auto;
  padding: 0;
  box-sizing: border-box;
}

.remote-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 3rem 1rem 1rem 1rem;
  box-sizing: border-box;
}

.remote-control {
  zoom: var(--scale);
  transition: zoom 0.2s ease;
  box-sizing: border-box;
}

/* Touchpad 3D animation */
.touchpad-perspective {
  display: flex;
  align-items: center;
  justify-content: center;
  perspective: 800px;
}

.touchpad {
  transform-origin: 50% 50%;
  transform: rotateX(0deg) rotateY(0deg);
  transition:
    transform 0.18s cubic-bezier(.25,.8,.25,1),
    transform-origin 0.18s cubic-bezier(.25,.8,.25,1);
}

/* Disable transition for instant press effect */
.touchpad.pressed-left,
.touchpad.pressed-right,
.touchpad.pressed-top,
.touchpad.pressed-bottom {
  transition: none;
}

/* Click left -> axis right, left side inward */
.touchpad.pressed-left {
  transform-origin: 100% 50%;
  transform: rotateY(-10deg) rotateX(0deg);
}

/* Click right -> axis left, right side inward */
.touchpad.pressed-right {
  transform-origin: 0% 50%;
  transform: rotateY(10deg) rotateX(0deg);
}

/* Click top -> axis bottom, top side inward */
.touchpad.pressed-top {
  transform-origin: 50% 100%;
  transform: rotateX(10deg) rotateY(0deg);
}

/* Click bottom -> axis top, bottom side inward */
.touchpad.pressed-bottom {
  transform-origin: 50% 0%;
  transform: rotateX(-10deg) rotateY(0deg);
}
</style>

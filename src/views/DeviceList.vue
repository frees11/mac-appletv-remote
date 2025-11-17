<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useApi } from '@/composables/useApi'
import type { Device } from '@/types'

const router = useRouter()
const api = useApi()

const devices = ref<Device[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const pairingDevice = ref<string | null>(null)
const pairingPin = ref('')
const waitingForPin = ref(false)
const pairingLoading = ref(false)
const timeExpired = ref(false)
const pinInput = ref<HTMLInputElement | null>(null)
let pinTimeout: NodeJS.Timeout | null = null

const CACHE_KEY = 'atv_remote_devices'
const CACHE_EXPIRY = 1000 * 60 * 60 * 24 // 24 hours

// Filter to only show Apple TV devices
const appleTVDevices = computed(() => {
  return devices.value.filter(device => {
    // Check if it's an Apple TV by looking at the model
    const model = device.model?.toLowerCase() || ''
    const name = device.name?.toLowerCase() || ''

    // Filter out MacBooks and other devices
    if (name.includes('macbook') || name.includes('mac') || model.includes('macbook')) {
      return false
    }

    // Include devices that look like Apple TVs
    return model.includes('appletv') ||
           model.includes('gen4k') ||
           model.includes('gen') ||
           name.includes('apple tv') ||
           name.includes('appletv')
  })
})

const loadCachedDevices = () => {
  try {
    const cached = localStorage.getItem(CACHE_KEY)
    if (cached) {
      const data = JSON.parse(cached)
      if (data.timestamp && Date.now() - data.timestamp < CACHE_EXPIRY) {
        devices.value = data.devices || []
        return true
      }
    }
  } catch (e) {
    console.error('Failed to load cached devices:', e)
  }
  return false
}

const saveCachedDevices = (devicesList: Device[]) => {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({
      devices: devicesList,
      timestamp: Date.now()
    }))
  } catch (e) {
    console.error('Failed to cache devices:', e)
  }
}

const scanDevices = async () => {
  loading.value = true
  error.value = null

  try {
    const newDevices = await api.fetchDevices()

    // Merge with existing devices, keeping paired status
    const mergedDevices = newDevices.map(newDevice => {
      const existing = devices.value.find(d => d.identifier === newDevice.identifier)
      return existing ? { ...newDevice, paired: existing.paired || newDevice.paired } : newDevice
    })

    devices.value = mergedDevices
    saveCachedDevices(mergedDevices)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to scan devices'
  } finally {
    loading.value = false
  }
}

const selectDevice = async (device: Device, event: Event) => {
  // Don't navigate if clicking the pair/unpair button
  const target = event.target as HTMLElement
  if (target.closest('button')) {
    return
  }

  // If device is not paired, start pairing immediately
  if (!device.paired) {
    await startPairing(device)
    return
  }

  // If paired, try to connect and navigate to remote
  try {
    await api.connectDevice(device.identifier)

    // Store device info in sessionStorage for instant display
    sessionStorage.setItem(`device_${device.identifier}`, JSON.stringify({
      name: device.name,
      address: device.address,
      model: device.model,
      identifier: device.identifier
    }))

    router.push(`/remote/${device.identifier}`)
  } catch (e) {
    const errorMsg = e instanceof Error ? e.message : 'Failed to connect'
    error.value = errorMsg
  }
}

const pairDevice = async (device: Device, event: Event) => {
  event.stopPropagation()
  await startPairing(device)
}

const startPairing = async (device: Device) => {
  pairingDevice.value = device.identifier
  pairingPin.value = ''
  waitingForPin.value = false
  pairingLoading.value = true
  timeExpired.value = false
  error.value = null

  // Clear any existing timeout
  if (pinTimeout) {
    clearTimeout(pinTimeout)
    pinTimeout = null
  }

  // Start pairing process on backend
  try {
    const result = await api.pairDevice(device.identifier)

    if (result.provide_pin) {
      // We show a PIN for user to enter on Apple TV
      pairingLoading.value = false
      pairingDevice.value = null
      alert(`Please enter this PIN on your Apple TV:\n\n${result.pin}\n\nThen click OK to continue.`)
      // After user enters PIN on Apple TV, complete pairing
      const finalResult = await api.pairDevice(device.identifier, result.pin)
      if (finalResult.success) {
        // Update local state immediately
        const deviceIndex = devices.value.findIndex(d => d.identifier === device.identifier)
        if (deviceIndex !== -1) {
          devices.value[deviceIndex].paired = true
          saveCachedDevices(devices.value)
        }
        alert('Pairing successful!')
        // Refresh in background
        scanDevices()
      } else {
        error.value = finalResult.error || 'Pairing failed'
      }
    } else if (result.needs_pin) {
      // Apple TV shows PIN, user enters it here
      // NOW show the dialog - only after ATV confirmed it displayed PIN
      pairingLoading.value = false
      waitingForPin.value = true
      console.log('Apple TV displayed PIN, showing dialog')

      // Set timeout to show resend option after 37 seconds
      pinTimeout = setTimeout(() => {
        timeExpired.value = true
      }, 37000)
    } else if (result.success) {
      pairingLoading.value = false
      pairingDevice.value = null
      // Update local state immediately
      const deviceIndex = devices.value.findIndex(d => d.identifier === device.identifier)
      if (deviceIndex !== -1) {
        devices.value[deviceIndex].paired = true
        saveCachedDevices(devices.value)
      }
      alert('Pairing successful!')
      // Refresh in background
      scanDevices()
    } else {
      pairingLoading.value = false
      error.value = result.error || 'Pairing failed'
      pairingDevice.value = null
    }
  } catch (e) {
    pairingLoading.value = false
    error.value = e instanceof Error ? e.message : 'Failed to start pairing'
    pairingDevice.value = null
  }
}

const submitPairing = async () => {
  if (!pairingDevice.value || !pairingPin.value) return

  // Clear timeout when submitting
  if (pinTimeout) {
    clearTimeout(pinTimeout)
    pinTimeout = null
  }

  try {
    console.log('Submitting PIN:', pairingPin.value)
    const result = await api.pairDevice(pairingDevice.value, pairingPin.value)

    if (result.success) {
      const deviceId = pairingDevice.value
      pairingDevice.value = null
      pairingPin.value = ''
      waitingForPin.value = false

      // Update local state immediately
      const deviceIndex = devices.value.findIndex(d => d.identifier === deviceId)
      if (deviceIndex !== -1) {
        devices.value[deviceIndex].paired = true
        saveCachedDevices(devices.value)
      }

      alert('✅ Pairing successful! You can now control your Apple TV.')
      // Refresh in background
      scanDevices()
    } else if (result.provide_pin) {
      alert(`Enter this PIN on your Apple TV: ${result.pin}`)
    } else {
      error.value = result.error || 'Pairing failed - please try again'
      waitingForPin.value = false
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Pairing failed'
    waitingForPin.value = false
  }
}

const cancelPairing = () => {
  // Clear timeout when canceling
  if (pinTimeout) {
    clearTimeout(pinTimeout)
    pinTimeout = null
  }
  pairingDevice.value = null
  waitingForPin.value = false
  pairingPin.value = ''
  timeExpired.value = false
}

const resendRequest = async () => {
  if (!pairingDevice.value) return

  const deviceId = pairingDevice.value
  const device = devices.value.find(d => d.identifier === deviceId)
  if (device) {
    await startPairing(device)
  }
}

const unpairDevice = async (device: Device, event: Event) => {
  event.stopPropagation()

  const confirmed = confirm(`Are you sure you want to unpair ${device.name}?\n\nYou will need to pair again to control this device.`)
  if (!confirmed) return

  try {
    await api.unpairDevice(device.identifier)

    // Update local state immediately
    const deviceIndex = devices.value.findIndex(d => d.identifier === device.identifier)
    if (deviceIndex !== -1) {
      devices.value[deviceIndex].paired = false
      saveCachedDevices(devices.value)
    }

    alert('Device unpaired successfully!')
    // Refresh in background
    scanDevices()
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to unpair device'
  }
}

// Auto-focus PIN input when pairing dialog opens
watch(waitingForPin, (isWaiting) => {
  if (isWaiting && !timeExpired.value) {
    // Use nextTick to ensure DOM is updated
    setTimeout(() => {
      pinInput.value?.focus()
    }, 100)
  }
})

onMounted(() => {
  // Load cached devices immediately for instant display
  const hasCached = loadCachedDevices()

  // Then scan for new/updated devices in the background
  scanDevices()

  if (!hasCached) {
    // If no cache, show initial message
    console.log('No cached devices, waiting for scan...')
  }
})
</script>

<template>
  <div class="device-list-wrapper min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 overflow-y-auto">
    <div class="device-list-content mx-auto max-w-7xl px-1.5 xs:px-3 sm:px-6 lg:px-8 pt-12 xs:pt-4 sm:pt-8 pb-8 xs:pb-12 sm:pb-20">
      <!-- Header -->
      <div class="mb-2 xs:mb-4 sm:mb-6 md:mb-8 text-center">
        <h1 class="text-base xs:text-lg sm:text-2xl md:text-3xl lg:text-4xl font-bold tracking-tight text-white">ATV Remote</h1>
        <p class="mt-0.5 xs:mt-1 sm:mt-2 text-[9px] xs:text-[10px] sm:text-xs md:text-sm text-gray-400">Control your Apple TV</p>
      </div>

      <!-- Error Message -->
      <div v-if="error" class="mb-2 xs:mb-3 sm:mb-6 rounded xs:rounded-md sm:rounded-lg bg-red-900/20 border border-red-500/30 p-1.5 xs:p-2.5 sm:p-4">
        <div class="flex items-start gap-1.5 xs:gap-2">
          <svg class="h-3.5 w-3.5 xs:h-4 xs:w-4 sm:h-5 sm:w-5 text-red-400 flex-shrink-0 mt-0.5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
          </svg>
          <p class="text-[10px] xs:text-[11px] sm:text-sm text-red-300">{{ error }}</p>
        </div>
      </div>

      <!-- Scan Button -->
      <div class="mb-2 xs:mb-3 sm:mb-6 flex justify-center">
        <button
          @click="scanDevices"
          :disabled="loading"
          type="button"
          class="inline-flex items-center gap-1 xs:gap-1.5 sm:gap-2 rounded xs:rounded-md sm:rounded-lg bg-gray-800 px-2 xs:px-2.5 sm:px-4 py-1 xs:py-1.5 sm:py-2 text-[10px] xs:text-[11px] sm:text-sm font-medium text-gray-300 hover:bg-gray-700 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 border border-gray-700"
        >
          <svg
            class="h-2.5 w-2.5 xs:h-3 xs:w-3 sm:h-4 sm:w-4"
            :class="{ 'animate-spin': loading }"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
          </svg>
          <span class="hidden xs:inline">{{ loading ? 'Scanning...' : 'Scan' }}</span>
          <span class="xs:hidden">{{ loading ? '...' : 'Scan' }}</span>
        </button>
      </div>

      <!-- Empty State -->
      <div v-if="!loading && appleTVDevices.length === 0" class="text-center py-4 xs:py-6 sm:py-12">
        <div class="mx-auto h-10 w-10 xs:h-12 xs:w-12 sm:h-20 sm:w-20 rounded-lg xs:rounded-xl sm:rounded-2xl bg-gray-800 flex items-center justify-center mb-1.5 xs:mb-2 sm:mb-4">
          <svg class="h-5 w-5 xs:h-6 xs:w-6 sm:h-10 sm:w-10 text-gray-600" viewBox="0 0 24 24" fill="currentColor">
            <path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z"/>
          </svg>
        </div>
        <h3 class="text-sm xs:text-base sm:text-xl font-semibold text-white mb-0.5 xs:mb-1 sm:mb-2">No devices</h3>
        <p class="text-[10px] xs:text-[11px] sm:text-base text-gray-400 px-2 xs:px-4">Click Scan</p>
      </div>

      <!-- Device Grid -->
      <div class="grid gap-1.5 xs:gap-2 sm:gap-4 md:gap-5 lg:gap-6 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3">
        <div
          v-for="device in appleTVDevices"
          :key="device.identifier"
          @click="selectDevice(device, $event)"
          class="group relative overflow-hidden rounded xs:rounded-md sm:rounded-xl bg-gradient-to-br from-gray-800 to-gray-900 p-2 xs:p-3 sm:p-5 md:p-6 border border-gray-700 hover:border-purple-500/50 cursor-pointer shadow-[0_10px_15px_-3px_rgb(0_0_0/0.1),0_4px_6px_-4px_rgb(0_0_0/0.1)] hover:shadow-[0_20px_25px_-5px_rgba(168,85,247,0.4),0_8px_10px_-6px_rgba(168,85,247,0.2)] transition-all duration-300 ease-out"
        >
          <!-- Glow Effect -->
          <div class="absolute inset-0 bg-gradient-to-br from-purple-500/0 to-purple-600/0 group-hover:from-purple-500/10 group-hover:to-purple-600/10 transition-all duration-300 ease-out"></div>

          <div class="relative">
            <!-- Header -->
            <div class="flex items-start justify-between mb-1.5 xs:mb-2 sm:mb-4 gap-1">
              <div class="flex h-6 w-6 xs:h-8 xs:w-8 sm:h-12 sm:w-12 items-center justify-center rounded xs:rounded-md sm:rounded-lg bg-gradient-to-br from-purple-500/20 to-purple-600/20 flex-shrink-0">
                <svg class="h-3 w-3 xs:h-4 xs:w-4 sm:h-6 sm:w-6 text-purple-400" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z"/>
                </svg>
              </div>
              <span
                v-if="device.paired"
                class="inline-flex items-center gap-0.5 xs:gap-1 sm:gap-1.5 rounded-full bg-green-500/20 px-1 xs:px-1.5 sm:px-3 py-0.5 text-[8px] xs:text-[9px] sm:text-xs font-semibold text-green-400 border border-green-500/30 flex-shrink-0"
              >
                <span>✓</span>
              </span>
              <span
                v-else
                class="inline-flex items-center rounded-full bg-orange-500/20 px-1 xs:px-1.5 sm:px-3 py-0.5 text-[8px] xs:text-[9px] sm:text-xs font-semibold text-orange-400 border border-orange-500/30 flex-shrink-0"
              >
                <span>⚠</span>
              </span>
            </div>

            <!-- Device Info -->
            <div class="mb-1.5 xs:mb-2 sm:mb-4">
              <h3 class="text-xs xs:text-sm sm:text-lg font-semibold text-white mb-0.5 group-hover:text-purple-300 transition-colors line-clamp-1">
                {{ device.name }}
              </h3>
              <p class="text-[9px] xs:text-[10px] sm:text-sm text-gray-400 font-mono mb-0.5 break-all line-clamp-1">{{ device.address }}</p>
              <p v-if="device.model" class="text-[8px] xs:text-[9px] sm:text-xs text-gray-500 line-clamp-1">{{ device.model }}</p>
            </div>

            <!-- Pair/Unpair Button -->
            <div class="pt-1.5 xs:pt-2 sm:pt-4 border-t border-gray-700">
              <button
                v-if="!device.paired"
                @click="pairDevice(device, $event)"
                type="button"
                class="w-full inline-flex items-center justify-center gap-0.5 xs:gap-1 sm:gap-2 rounded xs:rounded-md sm:rounded-lg bg-purple-600 px-1.5 xs:px-2 sm:px-4 py-1 xs:py-1.5 sm:py-2.5 text-[10px] xs:text-[11px] sm:text-sm font-semibold text-white hover:bg-purple-500 transition-colors duration-200 shadow-lg shadow-purple-600/30"
              >
                <svg class="h-2.5 w-2.5 xs:h-3 xs:w-3 sm:h-4 sm:w-4" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z" clip-rule="evenodd" />
                </svg>
                <span>Pair</span>
              </button>
              <button
                v-else
                @click="unpairDevice(device, $event)"
                type="button"
                class="w-full inline-flex items-center justify-center gap-0.5 xs:gap-1 sm:gap-2 rounded xs:rounded-md sm:rounded-lg bg-red-600 px-1.5 xs:px-2 sm:px-4 py-1 xs:py-1.5 sm:py-2.5 text-[10px] xs:text-[11px] sm:text-sm font-semibold text-white hover:bg-red-500 transition-colors duration-200 shadow-lg shadow-red-600/30"
              >
                <svg class="h-2.5 w-2.5 xs:h-3 xs:w-3 sm:h-4 sm:w-4" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
                </svg>
                <span>Unpair</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Loading Modal -->
    <Transition
      enter-active-class="transition ease-out duration-300"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition ease-in duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="pairingLoading"
        class="fixed inset-0 z-50 overflow-y-auto"
      >
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div class="fixed inset-0 bg-black/80 backdrop-blur-sm transition-opacity"></div>

          <div class="relative transform overflow-hidden rounded-lg xs:rounded-xl sm:rounded-2xl bg-gray-900 border border-gray-700 px-3 xs:px-4 pb-3 xs:pb-4 pt-4 xs:pt-5 text-left shadow-2xl transition-all sm:my-8 sm:w-full sm:max-w-sm sm:p-8">
            <!-- Loading Spinner -->
            <div class="flex flex-col items-center justify-center py-4 xs:py-6 sm:py-8">
              <div class="mb-3 xs:mb-4 sm:mb-6">
                <svg class="animate-spin h-10 w-10 xs:h-12 xs:w-12 sm:h-16 sm:w-16 text-purple-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              </div>
              <h3 class="text-sm xs:text-base sm:text-lg font-semibold text-white mb-1 xs:mb-1.5 sm:mb-2">Pairing</h3>
              <p class="text-[10px] xs:text-xs sm:text-sm text-gray-400 text-center px-2">Waiting...</p>
            </div>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Pairing Modal -->
    <Transition
      enter-active-class="transition ease-out duration-300"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition ease-in duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="waitingForPin"
        class="fixed inset-0 z-50 overflow-y-auto"
        @click.self="cancelPairing"
      >
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div class="fixed inset-0 bg-black/80 backdrop-blur-sm transition-opacity"></div>

          <Transition
            enter-active-class="transition ease-out duration-300"
            enter-from-class="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
            enter-to-class="opacity-100 translate-y-0 sm:scale-100"
            leave-active-class="transition ease-in duration-200"
            leave-from-class="opacity-100 translate-y-0 sm:scale-100"
            leave-to-class="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          >
            <div class="relative transform overflow-hidden rounded-lg xs:rounded-xl sm:rounded-2xl bg-gray-900 border border-gray-700 px-3 xs:px-4 sm:px-6 pb-3 xs:pb-4 sm:pb-6 pt-4 xs:pt-5 text-left shadow-2xl transition-all sm:my-8 sm:w-full sm:max-w-lg md:p-8">
              <!-- Icon -->
              <div class="mx-auto flex h-12 w-12 xs:h-16 xs:w-16 sm:h-20 sm:w-20 items-center justify-center rounded-lg xs:rounded-xl sm:rounded-2xl bg-gradient-to-br from-purple-500/20 to-purple-600/20 mb-3 xs:mb-4 sm:mb-6">
                <svg class="h-6 w-6 xs:h-8 xs:w-8 sm:h-10 sm:w-10 text-purple-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z" clip-rule="evenodd" />
                </svg>
              </div>

              <!-- Title -->
              <div class="text-center mb-4 xs:mb-5 sm:mb-6 md:mb-8">
                <h3 class="text-base xs:text-xl sm:text-2xl font-bold text-white mb-1 xs:mb-1.5 sm:mb-2">
                  {{ timeExpired ? 'Expired' : 'Enter PIN' }}
                </h3>
                <p v-if="!timeExpired" class="text-[10px] xs:text-xs sm:text-sm text-gray-400 px-2">Enter 4-digit PIN from TV</p>
                <p v-if="!timeExpired" class="text-[9px] xs:text-[10px] sm:text-xs text-yellow-500 mt-1 xs:mt-1.5 sm:mt-2">⏱ 37s</p>
                <p v-if="timeExpired" class="text-[10px] xs:text-xs sm:text-sm text-red-400 px-2">Session expired</p>
              </div>

              <!-- PIN Input -->
              <div class="mb-3 xs:mb-4 sm:mb-6 md:mb-8">
                <div class="flex gap-1 xs:gap-1.5 sm:gap-2 md:gap-3 justify-center" @click="!timeExpired && $refs.pinInput?.focus()">
                  <div
                    v-for="i in 4"
                    :key="i"
                    class="relative w-9 h-12 xs:w-10 xs:h-14 sm:w-12 sm:h-16 md:w-16 md:h-20 rounded xs:rounded-md sm:rounded-lg border-2 bg-gray-800 flex items-center justify-center transition-all"
                    :class="[
                      timeExpired ? 'border-gray-700 opacity-50 cursor-not-allowed' : 'border-gray-700 cursor-text',
                      !timeExpired && pairingPin.length >= i ? 'border-purple-500 ring-2 ring-purple-500/20' : ''
                    ]"
                  >
                    <span class="text-lg xs:text-xl sm:text-2xl md:text-3xl font-bold text-white pointer-events-none font-mono tabular-nums">
                      {{ pairingPin[i - 1] || '•' }}
                    </span>
                  </div>
                </div>
                <input
                  ref="pinInput"
                  v-model="pairingPin"
                  type="text"
                  inputmode="numeric"
                  pattern="[0-9]*"
                  maxlength="4"
                  class="sr-only"
                  :disabled="timeExpired"
                  autofocus
                  @keyup.enter="pairingPin.length === 4 && !timeExpired && submitPairing()"
                />
              </div>

              <!-- Actions -->
              <div v-if="!timeExpired" class="flex gap-1.5 xs:gap-2 sm:gap-3">
                <button
                  @click="cancelPairing"
                  type="button"
                  class="flex-1 rounded xs:rounded-md sm:rounded-lg bg-gray-800 px-2 xs:px-3 sm:px-4 py-2 xs:py-2.5 sm:py-3 text-[10px] xs:text-xs sm:text-sm font-semibold text-white hover:bg-gray-700 border border-gray-700 transition-colors"
                >
                  Cancel
                </button>
                <button
                  @click="submitPairing"
                  type="button"
                  :disabled="pairingPin.length !== 4"
                  class="flex-1 rounded xs:rounded-md sm:rounded-lg bg-purple-600 px-2 xs:px-3 sm:px-4 py-2 xs:py-2.5 sm:py-3 text-[10px] xs:text-xs sm:text-sm font-semibold text-white hover:bg-purple-500 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-purple-600/30 transition-all"
                >
                  Submit
                </button>
              </div>

              <!-- Expired Actions -->
              <div v-else class="flex gap-1.5 xs:gap-2 sm:gap-3">
                <button
                  @click="cancelPairing"
                  type="button"
                  class="flex-1 rounded xs:rounded-md sm:rounded-lg bg-gray-800 px-2 xs:px-3 sm:px-4 py-2 xs:py-2.5 sm:py-3 text-[10px] xs:text-xs sm:text-sm font-semibold text-white hover:bg-gray-700 border border-gray-700 transition-colors"
                >
                  Close
                </button>
                <button
                  @click="resendRequest"
                  type="button"
                  class="flex-1 rounded xs:rounded-md sm:rounded-lg bg-purple-600 px-2 xs:px-3 sm:px-4 py-2 xs:py-2.5 sm:py-3 text-[10px] xs:text-xs sm:text-sm font-semibold text-white hover:bg-purple-500 shadow-lg shadow-purple-600/30 transition-all"
                >
                  Resend
                </button>
              </div>
            </div>
          </Transition>
        </div>
      </div>
    </Transition>
  </div>
</template>

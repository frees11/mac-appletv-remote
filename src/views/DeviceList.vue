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
const timeExpired = ref(false)
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
  // Don't navigate if clicking the pair button
  if ((event.target as HTMLElement).closest('.pair-button')) {
    return
  }

  // Try to connect directly first (like iOS)
  try {
    await api.connectDevice(device.identifier)
    router.push(`/remote/${device.identifier}`)
  } catch (e) {
    // Only show pairing if connection fails
    const errorMsg = e instanceof Error ? e.message : 'Failed to connect'

    // If it's a pairing error, offer to pair
    if (!device.paired || errorMsg.includes('pair')) {
      const shouldPair = confirm(`Connection failed. Would you like to pair with ${device.name}?`)
      if (shouldPair) {
        await startPairing(device)
      }
    } else {
      error.value = errorMsg
    }
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
  timeExpired.value = false
  error.value = null

  // Clear any existing timeout
  if (pinTimeout) {
    clearTimeout(pinTimeout)
    pinTimeout = null
  }

  // Start pairing process on backend immediately
  try {
    const result = await api.pairDevice(device.identifier)

    if (result.provide_pin) {
      // We show a PIN for user to enter on Apple TV
      waitingForPin.value = false
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
      // Keep modal open for PIN entry
      waitingForPin.value = true
      console.log('Waiting for PIN entry, modal should stay open')

      // Set timeout to show resend option after 60 seconds
      pinTimeout = setTimeout(() => {
        timeExpired.value = true
      }, 60000)
    } else if (result.success) {
      pairingDevice.value = null
      waitingForPin.value = false
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
      error.value = result.error || 'Pairing failed'
      pairingDevice.value = null
      waitingForPin.value = false
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to start pairing'
    pairingDevice.value = null
    waitingForPin.value = false
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
  <div class="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
    <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8 pb-20">
      <!-- Header -->
      <div class="mb-8 text-center">
        <h1 class="text-3xl font-bold tracking-tight text-white sm:text-4xl">ATV Remote</h1>
        <p class="mt-2 text-sm text-gray-400">Control your Apple TV devices</p>
      </div>

      <!-- Error Message -->
      <div v-if="error" class="mb-6 rounded-lg bg-red-900/20 border border-red-500/30 p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm text-red-300">{{ error }}</p>
          </div>
        </div>
      </div>

      <!-- Scan Button -->
      <div class="mb-6 flex justify-center">
        <button
          @click="scanDevices"
          :disabled="loading"
          type="button"
          class="inline-flex items-center gap-2 rounded-lg bg-gray-800 px-4 py-2 text-sm font-medium text-gray-300 hover:bg-gray-700 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 border border-gray-700"
        >
          <svg
            class="h-4 w-4"
            :class="{ 'animate-spin': loading }"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
          </svg>
          {{ loading ? 'Scanning...' : 'Scan for devices' }}
        </button>
      </div>

      <!-- Empty State -->
      <div v-if="!loading && appleTVDevices.length === 0" class="text-center py-12">
        <div class="mx-auto h-20 w-20 rounded-2xl bg-gray-800 flex items-center justify-center mb-4">
          <svg class="h-10 w-10 text-gray-600" viewBox="0 0 24 24" fill="currentColor">
            <path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z"/>
          </svg>
        </div>
        <h3 class="text-xl font-semibold text-white mb-2">No Apple TVs Found</h3>
        <p class="text-gray-400">Click "Scan for devices" to search for Apple TVs on your network</p>
      </div>

      <!-- Device Grid -->
      <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <div
          v-for="device in appleTVDevices"
          :key="device.identifier"
          @click="selectDevice(device, $event)"
          class="group relative overflow-hidden rounded-xl bg-gradient-to-br from-gray-800 to-gray-900 p-6 border border-gray-700 hover:border-purple-500/50 cursor-pointer shadow-[0_10px_15px_-3px_rgb(0_0_0/0.1),0_4px_6px_-4px_rgb(0_0_0/0.1)] hover:shadow-[0_20px_25px_-5px_rgba(168,85,247,0.4),0_8px_10px_-6px_rgba(168,85,247,0.2)] transition-all duration-300 ease-out"
        >
          <!-- Glow Effect -->
          <div class="absolute inset-0 bg-gradient-to-br from-purple-500/0 to-purple-600/0 group-hover:from-purple-500/10 group-hover:to-purple-600/10 transition-all duration-300 ease-out"></div>

          <div class="relative">
            <!-- Header -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-gradient-to-br from-purple-500/20 to-purple-600/20">
                <svg class="h-6 w-6 text-purple-400" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z"/>
                </svg>
              </div>
              <span
                v-if="device.paired"
                class="inline-flex items-center gap-1.5 rounded-full bg-green-500/20 px-3 py-1 text-xs font-semibold text-green-400 border border-green-500/30"
              >
                <svg class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z" clip-rule="evenodd" />
                </svg>
                Paired
              </span>
              <span
                v-else
                class="inline-flex items-center rounded-full bg-orange-500/20 px-3 py-1 text-xs font-semibold text-orange-400 border border-orange-500/30"
              >
                Not Paired
              </span>
            </div>

            <!-- Device Info -->
            <div class="mb-4">
              <h3 class="text-lg font-semibold text-white mb-1 group-hover:text-purple-300 transition-colors">
                {{ device.name }}
              </h3>
              <p class="text-sm text-gray-400 font-mono mb-1">{{ device.address }}</p>
              <p v-if="device.model" class="text-xs text-gray-500">{{ device.model }}</p>
            </div>

            <!-- Pair Button -->
            <div v-if="!device.paired" class="pt-4 border-t border-gray-700">
              <button
                @click="pairDevice(device, $event)"
                type="button"
                class="w-full inline-flex items-center justify-center gap-2 rounded-lg bg-purple-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-purple-500 transition-colors duration-200 shadow-lg shadow-purple-600/30"
              >
                <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z" clip-rule="evenodd" />
                </svg>
                Pair Device
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

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
            <div class="relative transform overflow-hidden rounded-2xl bg-gray-900 border border-gray-700 px-4 pb-4 pt-5 text-left shadow-2xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-8">
              <!-- Icon -->
              <div class="mx-auto flex h-20 w-20 items-center justify-center rounded-2xl bg-gradient-to-br from-purple-500/20 to-purple-600/20 mb-6">
                <svg class="h-10 w-10 text-purple-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z" clip-rule="evenodd" />
                </svg>
              </div>

              <!-- Title -->
              <div class="text-center mb-8">
                <h3 class="text-2xl font-bold text-white mb-2">Enter PIN from Apple TV</h3>
                <p class="text-sm text-gray-400">Look at your Apple TV screen and enter the 4-digit PIN</p>
                <p v-if="!timeExpired" class="text-xs text-yellow-500 mt-2">⏱ Session expires in 60 seconds</p>
                <p v-else class="text-xs text-red-500 mt-2">⏱ Session expired - please resend request</p>
              </div>

              <!-- PIN Input -->
              <div class="mb-8">
                <div class="flex gap-3 justify-center" @click="$refs.pinInput?.focus()">
                  <div
                    v-for="i in 4"
                    :key="i"
                    class="relative w-16 h-20 rounded-xl border-2 border-gray-700 bg-gray-800 flex items-center justify-center transition-all cursor-text"
                    :class="pairingPin.length >= i ? 'border-purple-500 ring-2 ring-purple-500/20' : ''"
                  >
                    <span class="text-3xl font-bold text-white pointer-events-none font-mono tabular-nums">
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
                  autofocus
                  @keyup.enter="pairingPin.length === 4 && submitPairing()"
                />
              </div>

              <!-- Actions -->
              <div class="flex gap-3">
                <button
                  @click="cancelPairing"
                  type="button"
                  class="flex-1 rounded-lg bg-gray-800 px-4 py-3 text-sm font-semibold text-white hover:bg-gray-700 border border-gray-700 transition-colors"
                >
                  Cancel
                </button>
                <button
                  v-if="timeExpired"
                  @click="resendRequest"
                  type="button"
                  class="flex-1 rounded-lg bg-orange-600 px-4 py-3 text-sm font-semibold text-white hover:bg-orange-500 shadow-lg shadow-orange-600/30 transition-all"
                >
                  Resend Request
                </button>
                <button
                  v-else
                  @click="submitPairing"
                  type="button"
                  :disabled="pairingPin.length !== 4"
                  class="flex-1 rounded-lg bg-purple-600 px-4 py-3 text-sm font-semibold text-white hover:bg-purple-500 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-purple-600/30 transition-all"
                >
                  Submit PIN
                </button>
              </div>
            </div>
          </Transition>
        </div>
      </div>
    </Transition>
  </div>
</template>

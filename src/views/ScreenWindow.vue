<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useWebSocket } from '@/composables/useWebSocket'
import ScreenStream from '@/components/ScreenStream.vue'

const route = useRoute()
const deviceId = route.params.id as string

const WS_URL = import.meta.env.VITE_WS_URL || 'ws://localhost:8000/ws/control'
const { connect, disconnect, send, onMessage, onConnected } = useWebSocket(WS_URL)

const screenStreamRef = ref<InstanceType<typeof ScreenStream> | null>(null)
const streamError = ref<string | null>(null)
const deviceName = ref<string>('')
const showTutorial = ref(false)

const handleStreamError = (message: string) => {
  console.error('Stream error:', message)
  streamError.value = message
  showTutorial.value = true

  setTimeout(() => {
    streamError.value = null
  }, 15000)
}

onMounted(async () => {
  // Get device name from query param
  deviceName.value = (route.query.name as string) || 'Apple TV'

  // Set up message handler
  onMessage((message) => {
    console.log('Received WebSocket message:', message)

    if (message.type === 'screenshot_frame') {
      if (screenStreamRef.value && message.payload.image) {
        screenStreamRef.value.handleFrameReceived(message.payload.image)
      }
    } else if (message.type === 'screenshot_error') {
      if (screenStreamRef.value) {
        screenStreamRef.value.handleError(message.payload.message)
      }
    } else if (message.type === 'error') {
      console.error('WebSocket error:', message.payload)
      streamError.value = message.payload.message
      setTimeout(() => {
        streamError.value = null
      }, 10000)
    }
  })

  // Start streaming when WebSocket connects
  onConnected(() => {
    console.log('WebSocket connected, starting screenshot stream...')
    send({
      type: 'start_screenshot_stream',
      payload: {
        device_id: deviceId,
        interval: 0.2,
      },
    })
  })

  // Connect to WebSocket
  connect()
})

onUnmounted(() => {
  send({
    type: 'stop_screenshot_stream',
    payload: { device_id: deviceId },
  })
  disconnect()
})
</script>

<template>
  <div class="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex flex-col p-6">
    <!-- Header -->
    <div class="mb-6">
      <div class="flex items-center justify-between max-w-6xl mx-auto">
        <h1 class="text-2xl font-bold text-white">{{ deviceName }} - Screen View</h1>
        <button
          @click="showTutorial = !showTutorial"
          class="px-4 py-2 rounded-lg text-sm font-medium transition-all bg-blue-500/20 text-blue-300 border border-blue-500/30 hover:bg-blue-500/30"
        >
          {{ showTutorial ? '📺 Hide Tutorial' : '📖 Show Tutorial' }}
        </button>
      </div>
    </div>

    <!-- Tutorial Panel -->
    <div v-if="showTutorial" class="mb-6 max-w-6xl mx-auto w-full">
      <div class="bg-gradient-to-br from-blue-500/10 to-purple-500/10 border border-blue-500/30 rounded-2xl p-6 backdrop-blur-sm">
        <div class="flex items-start gap-3 mb-4">
          <div class="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center flex-shrink-0">
            <svg class="w-5 h-5 text-blue-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div class="flex-1">
            <h2 class="text-xl font-bold text-blue-100 mb-2">How to Enable Screen Streaming on Apple TV</h2>
            <p class="text-blue-200/80 text-sm mb-4">Screen streaming requires Developer Mode to be enabled on your Apple TV. Follow these steps:</p>
          </div>
        </div>

        <div class="space-y-6">
          <!-- Step 1 -->
          <div class="flex gap-4">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">1</div>
            </div>
            <div class="flex-1">
              <h3 class="text-white font-semibold mb-2">Install Xcode on Your Mac</h3>
              <p class="text-gray-300 text-sm mb-2">Download and install <span class="text-blue-300 font-medium">Xcode</span> from the Mac App Store (free)</p>
              <p class="text-gray-400 text-xs">Developer Mode on Apple TV only activates when paired with Xcode</p>
            </div>
          </div>

          <!-- Step 2 -->
          <div class="flex gap-4">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">2</div>
            </div>
            <div class="flex-1">
              <h3 class="text-white font-semibold mb-2">Connect Apple TV and Mac to Same Network</h3>
              <p class="text-gray-300 text-sm mb-2">Make sure both your Mac and Apple TV are connected to the <span class="text-blue-300 font-medium">same Wi-Fi network</span></p>
              <div class="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-3 mt-2">
                <p class="text-yellow-200 text-sm flex items-start gap-2">
                  <svg class="w-5 h-5 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  <span><strong>Important:</strong> If your network has both 2.4GHz and 5GHz bands with the same name, ensure both devices connect to the same band</span>
                </p>
              </div>
            </div>
          </div>

          <!-- Step 3 -->
          <div class="flex gap-4">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">3</div>
            </div>
            <div class="flex-1">
              <h3 class="text-white font-semibold mb-2">Enable Remote App and Devices on Apple TV</h3>
              <p class="text-gray-300 text-sm mb-2">On Apple TV, go to: <span class="text-blue-300 font-medium">Settings → Remotes and Devices → Remote App and Devices</span></p>
              <p class="text-gray-400 text-xs">This prepares your Apple TV to pair with Xcode</p>
            </div>
          </div>

          <!-- Step 4 -->
          <div class="flex gap-4">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">4</div>
            </div>
            <div class="flex-1">
              <h3 class="text-white font-semibold mb-2">Pair Apple TV with Xcode</h3>
              <p class="text-gray-300 text-sm mb-2">On your Mac, open <span class="text-blue-300 font-medium">Xcode → Window → Devices and Simulators</span></p>
              <p class="text-gray-300 text-sm mb-2">Your Apple TV should appear in the "Discovered" list. Click on it.</p>
              <p class="text-gray-300 text-sm">Enter the <span class="text-blue-300 font-medium">6-digit pairing code</span> shown on your Apple TV screen</p>
            </div>
          </div>

          <!-- Step 5 -->
          <div class="flex gap-4">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">5</div>
            </div>
            <div class="flex-1">
              <h3 class="text-white font-semibold mb-2">Developer Mode Activates Automatically</h3>
              <p class="text-gray-300 text-sm mb-2">After pairing, a new <span class="text-blue-300 font-medium">Developer</span> menu will appear in Apple TV Settings</p>
              <p class="text-gray-300 text-sm">Go to <span class="text-blue-300 font-medium">Settings → Developer</span> and enable <span class="text-blue-300 font-medium">Remote Access</span></p>
            </div>
          </div>

          <!-- Step 6 -->
          <div class="flex gap-4">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">6</div>
            </div>
            <div class="flex-1">
              <h3 class="text-white font-semibold mb-2">Start Tunnel Daemon (Terminal)</h3>
              <p class="text-gray-300 text-sm mb-2">Open Terminal and run this command:</p>
              <div class="bg-gray-800/50 border border-gray-700 rounded-lg p-3 mb-2">
                <code class="text-green-400 text-sm font-mono">sudo python3 -m pymobiledevice3 remote tunneld</code>
              </div>
              <p class="text-gray-400 text-xs mb-2">This command creates a network tunnel for screen streaming (requires admin password)</p>
              <div class="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-3">
                <p class="text-yellow-200 text-sm flex items-start gap-2">
                  <svg class="w-5 h-5 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  <span><strong>Important:</strong> Keep this Terminal window open while using screen streaming. The tunnel daemon must stay running.</span>
                </p>
              </div>
            </div>
          </div>

          <!-- Step 7 -->
          <div class="flex gap-4">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center text-white font-bold text-sm">✓</div>
            </div>
            <div class="flex-1">
              <h3 class="text-white font-semibold mb-2">You're All Set!</h3>
              <p class="text-gray-300 text-sm mb-2">Screen streaming should now work. The stream will appear below.</p>
              <p class="text-gray-400 text-xs">Note: Developer menu disappears after Apple TV restart, but reappears when you open Xcode and pair again</p>
            </div>
          </div>
        </div>

        <!-- Additional Info -->
        <div class="mt-6 pt-6 border-t border-blue-500/20">
          <h3 class="text-white font-semibold mb-3 flex items-center gap-2">
            <svg class="w-5 h-5 text-blue-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Additional Information
          </h3>
          <ul class="space-y-2 text-sm text-gray-300">
            <li class="flex items-start gap-2">
              <span class="text-blue-400 mt-1">•</span>
              <span>Developer Mode is required for screen capturing functionality</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-blue-400 mt-1">•</span>
              <span>Screen streaming may have a slight delay (200-500ms) depending on your network</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-blue-400 mt-1">•</span>
              <span>Make sure your Apple TV and this computer are on the same network</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-blue-400 mt-1">•</span>
              <span>You can disable Developer Mode after using screen streaming if desired</span>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Stream Error Message -->
    <div v-if="streamError" class="mb-6 max-w-6xl mx-auto w-full">
      <div class="px-6 py-4 bg-red-500/10 border border-red-500/30 rounded-xl backdrop-blur-sm">
        <div class="flex items-start gap-3">
          <svg class="w-6 h-6 text-red-400 flex-shrink-0 mt-0.5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
          </svg>
          <div class="flex-1">
            <p class="text-base font-semibold text-red-300 mb-1">Screen Streaming Error</p>
            <p class="text-sm text-red-200 mb-2">{{ streamError }}</p>
            <p class="text-sm text-red-200/70">💡 Follow the tutorial above to enable Developer Mode on your Apple TV</p>
          </div>
          <button @click="streamError = null; showTutorial = false" class="text-red-300 hover:text-red-200 transition-colors">
            <svg class="w-5 h-5" viewBox="0 0 20 20" fill="currentColor">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Screen Stream -->
    <div class="flex-1 flex items-center justify-center">
      <div class="w-full max-w-6xl">
        <ScreenStream
          ref="screenStreamRef"
          :device-id="deviceId"
          :is-streaming="true"
          @error="handleStreamError"
        />
      </div>
    </div>
  </div>
</template>

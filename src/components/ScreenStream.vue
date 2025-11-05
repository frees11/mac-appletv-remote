<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'

const props = defineProps<{
  deviceId: string
  isStreaming: boolean
}>()

const emit = defineEmits<{
  (e: 'update:isStreaming', value: boolean): void
  (e: 'error', message: string): void
}>()

const currentFrame = ref<string | null>(null)
const isLoading = ref(true)
const frameCount = ref(0)
const lastFrameTime = ref<number>(Date.now())
const fps = ref(0)

const imageDataUrl = computed(() => {
  if (!currentFrame.value) return null
  return `data:image/jpeg;base64,${currentFrame.value}`
})

const handleFrameReceived = (imageBase64: string) => {
  currentFrame.value = imageBase64
  isLoading.value = false
  frameCount.value++

  const now = Date.now()
  const timeDiff = (now - lastFrameTime.value) / 1000
  if (timeDiff > 0) {
    fps.value = Math.round(1 / timeDiff * 10) / 10
  }
  lastFrameTime.value = now
}

const handleError = (message: string) => {
  isLoading.value = false
  emit('error', message)
}

defineExpose({
  handleFrameReceived,
  handleError,
})

onMounted(() => {
  console.log('ScreenStream mounted for device:', props.deviceId)
})

onUnmounted(() => {
  currentFrame.value = null
})
</script>

<template>
  <div class="screen-stream-container">
    <div
      v-if="isLoading && isStreaming"
      class="loading-state bg-black/80 rounded-2xl p-8 flex flex-col items-center justify-center min-h-[200px]"
    >
      <div class="spinner w-12 h-12 border-4 border-white/20 border-t-white rounded-full animate-spin mb-4"></div>
      <p class="text-white text-sm">Connecting to Apple TV...</p>
      <p class="text-white/60 text-xs mt-2">This may take a few seconds</p>
    </div>

    <div
      v-else-if="currentFrame"
      class="stream-viewer bg-black rounded-2xl overflow-hidden relative"
    >
      <img
        :src="imageDataUrl"
        alt="Apple TV Screen"
        class="w-full h-auto block"
      />

      <div class="stream-stats absolute top-2 right-2 bg-black/70 backdrop-blur-sm px-3 py-1.5 rounded-lg text-xs text-white/80 font-mono">
        <span class="text-green-400">●</span> {{ fps }} fps
      </div>
    </div>

    <div
      v-else-if="!isStreaming"
      class="placeholder-state bg-gradient-to-br from-gray-800 to-gray-900 rounded-2xl p-8 flex flex-col items-center justify-center min-h-[200px] text-center"
    >
      <svg class="w-16 h-16 text-gray-600 mb-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <rect x="2" y="7" width="20" height="13" rx="2"/>
        <path d="M17 2l-5 5-5-5"/>
      </svg>
      <p class="text-gray-400 text-sm">Screen streaming disabled</p>
      <p class="text-gray-500 text-xs mt-2">Click "Show Screen" to start</p>
    </div>
  </div>
</template>

<style scoped>
.screen-stream-container {
  width: 100%;
}

.stream-viewer img {
  image-rendering: -webkit-optimize-contrast;
  image-rendering: crisp-edges;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.animate-spin {
  animation: spin 1s linear infinite;
}
</style>

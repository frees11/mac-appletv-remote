<script setup lang="ts">
import { RouterView } from 'vue-router'
</script>

<template>
  <div class="app-container">
    <div class="drag-region"></div>
    <RouterView />
  </div>
</template>

<style scoped>
.app-container {
  width: 100%;
  height: 100vh;
  background: linear-gradient(to bottom, #1c1c1e, #2c2c2e);
  overflow-y: auto;
  position: relative;
}

.drag-region {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 44px;
  -webkit-app-region: drag;
  z-index: 9999;
  pointer-events: none;
}

/* Allow buttons and interactive elements in the drag region */
.drag-region * {
  -webkit-app-region: no-drag;
  pointer-events: auto;
}
</style>

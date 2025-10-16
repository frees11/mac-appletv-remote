import { createRouter, createWebHashHistory } from 'vue-router'
import DeviceList from '@/views/DeviceList.vue'
import RemoteControl from '@/views/RemoteControl.vue'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: '/',
      name: 'devices',
      component: DeviceList,
    },
    {
      path: '/remote/:id',
      name: 'remote',
      component: RemoteControl,
      props: true,
    },
  ],
})

export default router

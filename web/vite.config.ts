import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5178,
    // 端口被占用时直接报错退出，不要自动递增到 5179/5180——
    // 多个 vite 实例会共享同一个 node_modules/.vite/deps 预打包缓存，
    // 互相覆盖后会出现"补丁失效"（如鱼骨图分支间距退回官方公式 → 节点重叠）
    strictPort: true,
    proxy: { '/api': 'http://127.0.0.1:5177' },
  },
});

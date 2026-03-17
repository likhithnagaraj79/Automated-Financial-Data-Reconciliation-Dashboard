import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
  build: {
    chunkSizeWarningLimit: 600,
    rollupOptions: {
      output: {
        // split recharts into its own chunk so it can be cached separately
        manualChunks: {
          recharts: ['recharts'],
          vendor: ['react', 'react-dom', 'axios'],
        },
      },
    },
  },
})

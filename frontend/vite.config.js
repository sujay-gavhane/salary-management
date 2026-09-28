import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Must match the backend's FRONTEND_ORIGIN (CORS + CSRF Origin check).
    port: 5173,
    strictPort: true,
    // Same-origin /api keeps the SameSite=Lax session cookie first-party in development.
    proxy: {
      '/api': process.env.API_PROXY_TARGET || 'http://localhost:3000',
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.js'],
    css: false,
    // Node's fetch can't resolve relative URLs, so tests use an absolute base (mocked by MSW).
    env: { VITE_API_URL: 'http://localhost/api/v1' },
  },
})

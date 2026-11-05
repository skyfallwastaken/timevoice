import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'
import path from 'node:path'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [
    svelte(),
    tailwindcss(),
    RubyPlugin(),
  ],
  resolve: {
    alias: {
      $lib: path.resolve('./app/frontend/lib'),
    },
  },
})

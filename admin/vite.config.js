import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Standard Vite + React setup. `npm run dev` serves on http://localhost:5173.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    open: true,
  },
  build: {
    // recharts is a large but acceptable single dependency for this panel.
    chunkSizeWarningLimit: 1200,
  },
});

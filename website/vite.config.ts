import { defineConfig } from "vite";
import { reactRouter } from "@react-router/dev/vite";
import netlifyReactRouter from "@netlify/vite-plugin-react-router";

export default defineConfig({
  plugins: [reactRouter(), netlifyReactRouter()],
  publicDir: "public",
  build: {
    minify: true,
    sourcemap: true,
  },
  server: {
    port: 5173,
    strictPort: true,
    host: true,
  },
});

import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: ["apps/server/src/tests/**/*.test.ts", "packages/shared/src/**/*.test.ts"]
  },
  resolve: {
    alias: {
      "@craftpresence/shared": new URL("./packages/shared/src/index.ts", import.meta.url).pathname
    }
  }
});

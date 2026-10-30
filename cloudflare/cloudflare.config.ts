import { bindings, defineConfig } from "cf/config";

import * as entrypoint from "./src/index.ts" with { type: "cf-worker" };

export default defineConfig({
  worker: {
    name: "raffronto",
    compatibilityDate: "2026-09-25",
    entrypoint,
    // everything is the static app in public/, except the share API
    assets: { runWorkerFirst: ["/api/*"] },
    env: {
      SHARES: bindings.r2({ name: "raffronto-shares" }),
    },
    domains: ["raffronto.app"],
    workersDev: true,
    observability: { enabled: true },
  },
});

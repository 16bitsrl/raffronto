import { bindings, defineConfig } from "cf/config";

import * as entrypoint from "./src/index.ts" with { type: "cf-worker" };

export default defineConfig({
  worker: {
    name: "raffronto",
    compatibilityDate: "2026-09-25",
    entrypoint,
    // everything is the static app in public/, except the share API and the app downloads (fetched from the
    // GitHub release by the Worker, see src/index.ts). Pages live at addresses without a trailing
    // slash: public/avvocati/index.html is served at /avvocati, and /avvocati/ redirects there
    assets: { runWorkerFirst: ["/api/*", "/download/*"], htmlHandling: "drop-trailing-slash" },
    env: {
      SHARES: bindings.r2({ name: "raffronto-shares" }),
    },
    domains: ["raffronto.app"],
    workersDev: true,
    observability: { enabled: true },
  },
});

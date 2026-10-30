// Builds the site (scripts/build.mjs, from src/) and copies it into public/, the static assets served by the Worker.
// src/ stays the only source: never edit site/ or public/ by hand.
import { execFileSync } from "node:child_process";
import { cpSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const out = join(here, "..", "public");

execFileSync(process.execPath, [join(root, "scripts", "build.mjs")], { stdio: "inherit" });
rmSync(out, { recursive: true, force: true });
cpSync(join(root, "site"), out, { recursive: true });
console.log("sync: public/ ready");

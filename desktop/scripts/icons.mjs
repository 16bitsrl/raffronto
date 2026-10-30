// Generates the app icons (src-tauri/icons) from the brand app icon (brand/logo/01-fogli-nastro/app-light.svg),
// or from the placeholder when the brand folder is missing. The brand master is a full square: it is placed
// in a rounded square with the macOS margins (824 of 1024 px), so it looks like the other icons in the Dock.
// Usage: node scripts/icons.mjs [source.svg]
import { existsSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const desktop = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const icons = join(desktop, 'src-tauri/icons');
const brand = resolve(desktop, '../brand/logo/01-fogli-nastro/app-light.svg');
let source = process.argv[2] ?? (existsSync(brand) ? brand : join(icons, 'placeholder.svg'));

if (source === brand) {
  const inner = readFileSync(brand, 'utf8').replace(/<\?xml[^>]*>/, '').replace(/<title[^>]*>.*?<\/title>/s, '')
    .replace(/\s(width|height|role|aria-labelledby)="[^"]*"/g, '');
  const wrapped = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs><clipPath id="r"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath></defs>
  <g clip-path="url(#r)">${inner.replace('<svg ', '<svg x="100" y="100" width="824" height="824" ')}</g>
  <rect x="100.5" y="100.5" width="823" height="823" rx="185" fill="none" stroke="#203A59" stroke-opacity=".12"/>
</svg>`;
  source = join(icons, 'app-icon.svg');
  writeFileSync(source, wrapped);
}
console.log(`icons: from ${source}`);
execFileSync('npx', ['tauri', 'icon', source, '-o', icons], { stdio: 'inherit', cwd: desktop });
// desktop only: no mobile icons
for (const d of ['android', 'ios']) rmSync(join(icons, d), { recursive: true, force: true });

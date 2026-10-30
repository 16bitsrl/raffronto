#!/bin/zsh
# Renders social.html to src/social.png and src/social-en.png (the link preview images).
# The browser refuses file: pages, so brand/ is served for a moment on a local port.
set -eu
here=${0:A:h}
port=$((47000 + RANDOM % 900))
uv run python -m http.server $port --bind 127.0.0.1 --directory $here/.. >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null' EXIT
sleep 1.5
s=raff-social-$$
playwright-cli -s=$s open about:blank >/dev/null
for lang in it en; do
  png=$here/../../src/social.png; [[ $lang == en ]] && png=$here/../../src/social-en.png
  playwright-cli -s=$s run-code "async page => { await page.setViewportSize({ width: 1200, height: 630 }); await page.goto('http://127.0.0.1:$port/social/social.html?lang=$lang'); await page.evaluate(() => document.fonts.ready); await page.screenshot({ path: '$png' }); return 'ok'; }" >/dev/null
done
playwright-cli -s=$s close >/dev/null
echo "src/social.png and src/social-en.png ready"

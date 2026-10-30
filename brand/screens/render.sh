#!/bin/zsh
# Screenshots of the app for the features recap of the landing pages: src/screens/<name>-<lang>-<theme>.webp.
# Real app, local site (Herd, http://diff-tracker.test/, built from src/), synthetic documents in tests/fixtures only.
# Usage: zsh brand/screens/render.sh   (URL= for another copy of the site; needs playwright-cli and cwebp)
# The sizes in CSS pixels below must match the width/height attributes of the images in src/index.html.
set -eu
here=${0:A:h}
root=${here:h:h}
URL=${URL:-http://diff-tracker.test/}
FX=$root/tests/fixtures
out=$root/src/screens
tmp=$(mktemp -d /tmp/raffronto-screens.XXXXXX)
mkdir -p $out
node $root/scripts/build.mjs >/dev/null
s=raff-screens-$$
playwright-cli -s=$s open about:blank >/dev/null
trap 'playwright-cli -s=$s close >/dev/null 2>&1; rm -rf $tmp' EXIT

for lang in it en; do
  home=$URL; [[ $lang == en ]] && home=${URL}en/
  for theme in light dark; do
    res=$(playwright-cli -s=$s run-code "async page => {
      const ctx = await page.context().browser().newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: '$lang' });
      await ctx.addInitScript(() => { localStorage.setItem('raffronto-theme', '$theme'); localStorage.setItem('raffronto-lang', '$lang'); });
      const p = await ctx.newPage();
      const shot = (name, clip) => p.screenshot({ path: '$tmp/' + name + '.png', clip });
      const load = async (a, b) => {
        await p.goto('$home'); await p.evaluate(() => document.fonts.ready);
        const ins = p.locator('.drop input'); await ins.nth(0).setInputFiles('$FX/' + a); await ins.nth(1).setInputFiles('$FX/' + b);
        await p.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); await p.waitForTimeout(1500);
      };
      const box = async sel => p.locator(sel).first().boundingBox();
      try {
        // the whole app: both versions side by side, one change lit on both sides (1440x900)
        await load('regulation-v1.docx', 'regulation-v2.docx');
        for (let i = 0; i < 5; i++) await p.keyboard.press('j');
        await p.waitForTimeout(700);
        await p.locator('.pane[data-side=\"1\"] mark.mk').nth(9).hover(); await p.waitForTimeout(400);
        await shot('compare');
        // the list of changes with its filters (360x420)
        const panel = await box('.panel');
        await shot('changes', { x: panel.x, y: panel.y, width: 360, height: 420 });
        // the download menu, Word comparison (340x460)
        await p.mouse.move(5, 500); await p.locator('#printBtn').click(); await p.waitForTimeout(400);
        const m = await box('#printMenu');
        await shot('download', { x: Math.round(m.x + m.width / 2 - 170), y: m.y - 12, width: 340, height: 460 });
        // Word tracked changes: the Accepted / Rejected switch with its explanation (488x300)
        await p.keyboard.press('Escape');
        await load('statute.docx', 'statute-revisions.docx');
        const pane = await box('.pane[data-side=\"1\"]');
        await shot('revisions', { x: pane.x, y: pane.y, width: 488, height: 300 });
        // a digital signature added between two signed PDFs: the ribbon and the new signature marked as added (540x405)
        await p.keyboard.press('Escape');
        await load('agreement-v2-signed.pdf', 'agreement-v2-countersigned.pdf');
        await p.keyboard.press('j'); await p.waitForTimeout(1200);
        const b = await box('.pane[data-side=\"1\"] .hl.vis');
        await shot('signatures', { x: Math.round(b.x + b.width + 36 - 540), y: Math.round(b.y + b.height / 2 - 215), width: 540, height: 405 });
        return 'ok';
      } finally { await ctx.close(); }
    }" 2>&1 | sed -n '/### Result/{n;p;}')
    [[ $res == '"ok"' ]] || { echo "render failed ($lang $theme): $res" >&2; exit 1; }
    for name in compare changes download revisions signatures; do
      opts=(-q 80 -m 6 -sharp_yuv -quiet)
      [[ $name == compare ]] && opts=(-q 74 -m 6 -sharp_yuv -quiet -resize 1960 0)
      cwebp $opts $tmp/$name.png -o $out/$name-$lang-$theme.webp
    done
  done
done
echo "src/screens ready: $(ls $out | wc -l | tr -d ' ') images, $(du -sh $out | cut -f1)"

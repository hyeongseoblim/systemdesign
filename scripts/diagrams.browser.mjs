// Run against a built/running web app. Uses read-only production card data.
import { chromium } from '../apps/web/node_modules/playwright/index.mjs';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = process.env.WEB_BASE || 'http://localhost:3400';
const api = process.env.API_BASE || 'https://jobstudy-api-u3uso2qdpa-du.a.run.app';
const output = process.env.DIAGRAM_ARTIFACTS || '/tmp/jobstudy-diagram-check';
await mkdir(output, { recursive: true });
const manifest = JSON.parse(await readFile(path.join(root, 'apps/web/content/diagrams.json'), 'utf8'));
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : undefined), headless: true });
try {
  const page = await browser.newPage();
  await page.goto(base + '/manifest.webmanifest');
  // Decode every asset with the actual browser SVG image decoder, not only an XML parser.
  const decoded = await page.evaluate(async ({ base, sources }) => {
    const failed = [];
    for (let i = 0; i < sources.length; i += 12) {
      await Promise.all(sources.slice(i, i + 12).map(async src => {
        const image = new Image(); image.src = base + src;
        try { await image.decode(); if (!image.naturalWidth || !image.naturalHeight) failed.push(src); }
        catch { failed.push(src); }
      }));
    }
    return failed;
  }, { base, sources: Object.values(manifest).map(x => x.src) });
  assert.deepEqual(decoded, [], 'SVG images must decode');
  let cards = [], cursor;
  do {
    const response = await fetch(api + '/api/v1/cards?limit=100' + (cursor ? '&cursor=' + encodeURIComponent(cursor) : ''));
    assert.ok(response.ok);
    const feed = await response.json(); cards.push(...feed.items); cursor = feed.nextCursor;
  } while (cursor);
  const slugs = ['logistics-19-event-pipeline-interview', 'backend-03-transaction', 'cs-02-os', 'system-design-04-data-storage', 'cs-09-os-network-interview'];
  const checks = [];
  for (const width of [320, 390, 768, 1280]) {
    await page.setViewportSize({ width, height: 900 });
    for (const slug of slugs) {
      const card = cards.find(x => x.slug === slug); assert.ok(card);
      await page.goto(`${base}/cards/${card.id}`);
      await page.locator('.diagram-image').first().waitFor();
      await page.waitForFunction(() => [...document.querySelectorAll('.diagram-image')].every(el => el.getBoundingClientRect().width > 0));
      for (const img of await page.locator('.diagram-image img').all()) {
        await img.scrollIntoViewIfNeeded();
        try { await img.evaluate(image => image.decode()); } catch (error) { throw new Error(`${slug} @ ${width}: ${(await img.getAttribute('src'))?.slice(0, 160)}: ${error.message}`); }
      }
      const errors = await page.locator('.diagram-image').evaluateAll(figures => figures.flatMap(el => {
        const issues = [];
        if (el.scrollWidth > el.clientWidth + 1) issues.push('figure overflow');
        for (const panel of el.querySelectorAll('.diagram-panel-viewport')) {
          const img = panel.querySelector('img');
          if (img.clientWidth <= panel.clientWidth) issues.push('panel did not enlarge');
          if (img.clientHeight + 2 < panel.clientHeight) issues.push('panel bottom missing');
        }
        if (!el.querySelector('img')) issues.push('missing diagram');
        return issues;
      }));
      assert.deepEqual(errors, [], `${slug} @ ${width}`);
      checks.push({ slug, width, figures: await page.locator('.diagram-image').count() });
      if (width === 390) {
        await page.locator('.reading-dock').evaluate(el => el.style.display = 'none');
        await page.locator('.diagram-image').first().screenshot({ path: `${output}/${slug}.png` });
      }
    }
  }
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload(); await page.locator('.diagram-image').first().waitFor();
  await page.locator('.reading-dock').evaluate(el => el.style.display = 'none');
  await page.locator('.diagram-image').first().screenshot({ path: `${output}/dark.png` });
  // Verify useful text remains available, including when images are hidden.
  await page.locator('.diagram-description summary').first().click();
  assert.ok((await page.locator('.diagram-description[open] pre').first().textContent()).length > 20);
  await writeFile(`${output}/results.json`, JSON.stringify({ decoded: Object.keys(manifest).length, checks }, null, 2));
  console.log(`Decoded ${Object.keys(manifest).length} SVG images; passed ${checks.length} card/viewport checks and dark/text checks.`);
} finally { await browser.close(); }

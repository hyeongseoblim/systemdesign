// Rebuild checked-in SVGs from the canonical Markdown; no API or database writes.
import { sequenceSvg } from './diagram-sequence.mjs';
import { chromium } from '../apps/web/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const web = path.join(root, 'apps/web');
const sources = new Map();
for (const file of (await readdir(path.join(root, 'apps/api/src/main/resources/content'))).sort()) {
  if (!file.endsWith('.md')) continue;
  const md = await readFile(path.join(root, 'apps/api/src/main/resources/content', file), 'utf8');
  for (const [, language, body] of md.matchAll(/^```([^\n]*)\n([\s\S]*?)^```/gm)) {
    const source = body.trim().replace(/\r\n/g, '\n');
    const linear = language.trim() === 'text' && (source.match(/→/g) || []).length >= 2 && !/[=()]/.test(source);
    const ascii = ['', 'text'].includes(language.trim()) && (/[┌┐└┘├┤│─]/.test(source) || source.includes('[Root]'));
    if (language.trim() === 'mermaid' || ascii || linear) sources.set(source, { file, ascii, linear });
  }
}
const server = createServer(async (req, res) => {
  try {
    const relative = decodeURIComponent(req.url.split('?')[0]);
    if (relative === '/') { res.setHeader('Content-Type', 'text/html'); res.end('<html><body></body></html>'); return; }
    const file = path.resolve(web, '.' + relative);
    if (!file.startsWith(web + path.sep)) { res.writeHead(403).end(); return; }
    res.setHeader('Content-Type', 'text/javascript'); res.end(await readFile(file));
  } catch { res.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : undefined), headless: true });
try {
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.evaluate(async () => {
    window.mermaid = (await import('/node_modules/mermaid/dist/mermaid.esm.min.mjs')).default;
    window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'neutral', htmlLabels: false,
      fontFamily: 'Arial, sans-serif', themeVariables: { fontSize: '16px' },
      flowchart: { htmlLabels: false, useMaxWidth: false, wrappingWidth: 180, nodeSpacing: 24, rankSpacing: 40 },
      sequence: { useMaxWidth: false, wrap: true, width: 120, actorMargin: 24 },
    });
  });
  await page.addScriptTag({ content: `window.sequenceSvg = ${sequenceSvg.toString()}` });
  const manifest = {};
  await mkdir(path.join(web, 'public/diagrams'), { recursive: true });
  let index = 0;
  for (const [source, { file, ascii, linear }] of sources) {
    const hash = createHash('sha256').update(source).digest('hex').slice(0, 20);
    const result = await page.evaluate(async ({ source, index, ascii, linear }) => {
      let svg;
      if (linear) {
        const steps = source.split(/\s*→\s*/).map(x => x.replace(/\s+/g, ' ').trim());
        const code = 'flowchart TB\n' + steps.map((text, i) => `n${i}[${JSON.stringify(text)}]`).join('\n') + '\n' + steps.slice(1).map((_, i) => `n${i} --> n${i + 1}`).join('\n');
        svg = (await window.mermaid.render(`diagram${index}`, code)).svg;
      } else if (ascii) {
        const escape = text => text.replace(/[&<>\"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
        const lines = source.split('\n');
        const canvas = document.createElement('canvas'); const context = canvas.getContext('2d'); context.font = '16px monospace';
        const width = Math.ceil(Math.max(...lines.map(line => context.measureText(line).width))) + 32;
        svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${lines.length * 26 + 32}"><g font-family="monospace" font-size="16" fill="#20242b">${lines.map((line, i) => `<text x="16" y="${i * 26 + 30}" xml:space="preserve">${escape(line)}</text>`).join('')}</g></svg>`;
      } else {
        let vertical = source.replace(/^(\s*(?:flowchart|graph))\s+(?:LR|RL)\b/m, '$1 TB').replace(/^(\s*direction\s+)(?:LR|RL)\b/gm, '$1TB');
        vertical = vertical.replace(/\|""\|/g, '');
        if (vertical.startsWith('sequenceDiagram')) vertical = vertical.replace(/;/g, '#59;');
        if (vertical.startsWith('sequenceDiagram')) {
          const diagram = await window.mermaid.mermaidAPI.getDiagramFromText(vertical);
          svg = window.sequenceSvg([...diagram.db.getActors()], diagram.db.getMessages(), diagram.db.LINETYPE, diagram.db.getDiagramTitle());
        } else svg = (await window.mermaid.render(`diagram${index}`, vertical)).svg;
      }
      const container = document.createElement('div'); container.innerHTML = svg;
      const doc = document; 
      const el = container.querySelector('svg'); const box = el.getAttribute('viewBox').split(/[ ,]+/).map(Number);
      el.removeAttribute('style'); el.removeAttribute('width'); el.removeAttribute('height');
      el.setAttribute('width', String(box[2])); el.setAttribute('height', String(box[3]));
      // SVG images have a stable light canvas in both application themes.
      const background = doc.createElementNS('http://www.w3.org/2000/svg', 'rect');
      for (const [key, value] of Object.entries({ x: box[0], y: box[1], width: box[2], height: box[3], fill: '#ffffff' })) background.setAttribute(key, String(value));
      el.insertBefore(background, el.firstChild);
      const panels = [];
      if (box[2] > 320) {
        const count = Math.ceil((box[2] - 300) / 150) + 1;
        const width = Math.min(300, box[2]);
        for (let i = 0; i < count; i++) {
          const x = box[0] + (box[2] - width) * i / (count - 1);
          panels.push({ offset: x - box[0], width, height: box[3] });
        }
      }
      return { svg: new XMLSerializer().serializeToString(el), width: box[2], height: box[3], panels };
    }, { source, index: index++, ascii, linear }).catch(error => { throw new Error(`${file}: ${error.message}`); });
    await writeFile(path.join(web, `public/diagrams/${hash}.svg`), result.svg);
    manifest[source] = { src: `/diagrams/${hash}.svg`, width: result.width, height: result.height, panels: result.panels };
  }
  await writeFile(path.join(web, 'content/diagrams.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(`Generated ${index} diagrams (${Object.values(manifest).filter(x => x.panels.length).length} with vertical detail panels).`);
} finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }

// Read-only local fixture built from the repository's real 129-card curriculum.
// IDs are deterministic test IDs; this script never connects to an operating DB.
import { createServer } from 'node:http';
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const folder = path.join(root, 'apps/api/src/main/resources/content');
const guides = JSON.parse(await readFile(path.join(root, 'apps/web/content/answer-guides.json'), 'utf8'));
const uuid = value => createHash('sha256').update(value).digest('hex').slice(0, 32).replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, '$1-$2-$3-$4-$5');
const cards = [];
for (const file of (await readdir(folder)).sort()) {
  if (!file.endsWith('.md')) continue;
  const markdown = await readFile(path.join(folder, file), 'utf8');
  const front = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/.exec(markdown);
  if (!front) throw new Error('Missing frontmatter: ' + file);
  function field(key) { const raw = new RegExp(`^${key}:\\s*(.+)$`, 'm').exec(front[1])?.[1]; if (raw == null) return null; try { return JSON.parse(raw); } catch { return raw; } }
  const slug = field('slug');
  cards.push({ id: uuid(slug), slug, title: field('title'), summary: field('summary'), area: field('area'), mode: field('mode'), coach: field('coach'), difficulty: field('difficulty'), tags: [], publishedAt: '2026-10-01T00:00:00Z', createdAt: '2026-10-01T00:00:00Z', status: 'PUBLISHED', source: 'MANUAL', qualityScore: null, contentMd: markdown.slice(front[0].length), questions: guides[slug].questions.map((q, index) => ({ id: uuid(`${slug}:${index}`), displayOrder: index, question: q.question })) });
}
const server = createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Access-Control-Allow-Origin', 'http://localhost:3000');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') { res.end(); return; }
  if (req.method !== 'GET') { res.writeHead(405).end('{}'); return; }
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/api/v1/health') { res.end('{"status":"UP","fixture":true}'); return; }
  if (url.pathname === '/api/v1/cards') {
    const matches = cards.filter(c => ['area', 'mode', 'difficulty'].every(key => !url.searchParams.get(key) || String(c[key]) === url.searchParams.get(key)));
    const offset = Math.max(0, Number(url.searchParams.get('cursor')) || 0), limit = Math.min(100, Math.max(1, Number(url.searchParams.get('limit')) || 20));
    const items = matches.slice(offset, offset + limit).map(({ contentMd, questions, ...summary }) => summary);
    res.end(JSON.stringify({ items, nextCursor: offset + limit < matches.length ? String(offset + limit) : null })); return;
  }
  const card = cards.find(c => url.pathname === `/api/v1/cards/${c.id}`);
  if (card) res.end(JSON.stringify(card)); else res.writeHead(404).end('{}');
});
server.listen(Number(process.env.FIXTURE_PORT || 8099), '127.0.0.1', () => console.log(`Read-only fixture API: http://localhost:${server.address().port} (${cards.length} cards)`));

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync, readdirSync } = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const web = path.join(root, 'apps/web');
const images = JSON.parse(readFileSync(path.join(web, 'content/diagrams.json')));

test('모든 Mermaid 및 문자 도표에 원본과 연결된 SVG 이미지가 있다', () => {
  let mermaid = 0, ascii = 0;
  for (const file of readdirSync(path.join(root, 'apps/api/src/main/resources/content'))) {
    if (!file.endsWith('.md')) continue;
    const md = readFileSync(path.join(root, 'apps/api/src/main/resources/content', file), 'utf8');
    for (const [, lang, body] of md.matchAll(/^```([^\n]*)\n([\s\S]*?)^```/gm)) {
      const source = body.trim().replace(/\r\n/g, '\n');
      const isAscii = ['', 'text'].includes(lang.trim()) && (/[┌┐└┘├┤│─]/.test(source) || source.includes('[Root]'));
      const isLinear = lang.trim() === 'text' && (source.match(/→/g) || []).length >= 2 && !/[=()]/.test(source);
      if (lang.trim() !== 'mermaid' && !isAscii && !isLinear) continue;
      lang.trim() === 'mermaid' ? mermaid++ : ascii++;
      const image = images[source]; assert.ok(image, file);
      assert.equal(image.src, `/diagrams/${createHash('sha256').update(source).digest('hex').slice(0,20)}.svg`);
      const svg = readFileSync(path.join(web, 'public', image.src), 'utf8');
      if (source.includes('BEGIN; SELECT qty (10)')) assert.match(svg, /BEGIN; SELECT qty \(10\)/);
      assert.doesNotMatch(svg, /ﬂ°|¶ß/, 'Mermaid entity placeholders must be decoded');
      if (source.startsWith('sequenceDiagram')) { assert.equal(image.width, 300); assert.equal(image.panels.length, 0); }
      assert.match(svg, /<svg\b/); assert.match(svg, /viewBox=/);
      assert.doesNotMatch(svg, /<script\b|<foreignObject\b|href="https?:/i);
      assert.ok(image.width > 0 && image.height > 0);
    }
  }
  assert.equal(mermaid, 266); assert.equal(ascii, 7);
});

test('넓은 도표의 세로 확대 구간은 양끝을 포함해 원본 전체를 빠짐없이 덮는다', () => {
  for (const image of Object.values(images)) {
    if (image.width <= 320) { assert.equal(image.panels.length, 0); continue; }
    assert.ok(image.panels.length > 1);
    assert.equal(image.panels[0].offset, 0);
    let end = 0;
    for (const panel of image.panels) {
      assert.ok(panel.offset <= end, image.src);
      assert.equal(panel.height, image.height);
      assert.ok(panel.width <= 300);
      end = panel.offset + panel.width;
    }
    assert.ok(Math.abs(end - image.width) < 0.001, image.src);
  }
});

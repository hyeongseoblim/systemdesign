#!/usr/bin/env node
// HTML 학습 산출물 스캔 → data/contents.json 생성.
// 자동 추출 + data/contents.manual.json 사이드카 머지.

import { readdir, readFile, stat, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, resolve } from 'node:path';
import { parseMeta } from './lib/html-meta-parser.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const SKIP_DIRS = new Set(['.git', '.claude', 'node_modules', 'assets', 'data', 'scripts']);
const SKIP_FILES = new Set(['index.html']);

async function findHtmlFiles(dir, out = []) {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const e of entries) {
    if (e.name.startsWith('.')) continue;
    if (SKIP_DIRS.has(e.name)) continue;
    const full = join(dir, e.name);
    if (e.isDirectory()) {
      await findHtmlFiles(full, out);
    } else if (e.isFile() && e.name.endsWith('.html') && !SKIP_FILES.has(e.name)) {
      out.push(full);
    }
  }
  return out;
}

async function loadManual() {
  const path = join(ROOT, 'data', 'contents.manual.json');
  if (!existsSync(path)) return {};
  try {
    return JSON.parse(await readFile(path, 'utf8'));
  } catch (err) {
    console.warn(`⚠️  data/contents.manual.json 파싱 실패: ${err.message}`);
    return {};
  }
}

function mergeManual(auto, manual) {
  const m = manual[auto.id] ?? {};
  return {
    ...auto,
    tags: m.tags ?? [],
    difficulty: m.difficulty ?? null,
    estimatedMinutes: m.estimatedMinutes ?? null,
    prerequisites: m.prerequisites ?? [],
    keywords: m.keywords ?? [],
    description: m.description ?? null,
  };
}

async function build() {
  const files = await findHtmlFiles(ROOT);
  files.sort();
  const manual = await loadManual();

  const items = [];
  for (const abs of files) {
    const rel = relative(ROOT, abs).replace(/\\/g, '/');
    const html = await readFile(abs, 'utf8');
    const stats = await stat(abs);
    const meta = parseMeta(html, rel);
    const lineCount = html.split('\n').length;
    const fileSizeKB = +(stats.size / 1024).toFixed(1);
    const updatedAt = stats.mtime.toISOString().slice(0, 10);
    const item = mergeManual(
      {
        ...meta,
        lineCount,
        fileSizeKB,
        updatedAt,
      },
      manual,
    );
    items.push(item);
  }

  // 카운트 검증 로그
  const missing = items.filter((it) => !it.coach || !it.mode);
  if (missing.length) {
    console.warn(`⚠️  coach/mode 추출 실패: ${missing.length}건`);
    for (const m of missing) console.warn(`   - ${m.path}: coach=${m.coach}, mode=${m.mode}`);
  }
  const noQa = items.filter((it) => it.qaCount === 0);
  if (noQa.length) {
    console.warn(`ℹ️  Q&A 답변 영역 없음: ${noQa.length}건`);
    for (const m of noQa) console.warn(`   - ${m.path}`);
  }

  const output = {
    version: 1,
    generatedAt: new Date().toISOString(),
    contents: items,
  };

  const outPath = join(ROOT, 'data', 'contents.json');
  await writeFile(outPath, JSON.stringify(output, null, 2) + '\n', 'utf8');
  console.log(`✅ ${items.length}개 항목 → data/contents.json`);
}

build().catch((err) => {
  console.error('❌ 빌드 실패:', err);
  process.exit(1);
});

#!/usr/bin/env node
// 학습 페이지에 study-widget 와이어링을 주입하는 idempotent 도구.
//
// 두 줄 변경:
//   1) `const NS='jobStudy::...::';` 다음에 `window.NS=NS;` 가 없으면 추가
//   2) `</body>` 직전에 `<script type="module" src="<상대경로>/assets/study-widget.js?v=1">` 가 없으면 추가
//
// 사용법:
//   node scripts/inject-widget.mjs --dry-run       # 변경 사항만 출력
//   node scripts/inject-widget.mjs                  # 실제 적용
//   node scripts/inject-widget.mjs path/to/file.html  # 특정 파일만
//
// 멱등성(idempotency): 이미 와이어링된 파일은 건드리지 않는다. 부분만 적용된 파일도
// 빠진 부분만 채운다.

import { readdir, readFile, writeFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, resolve, sep } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const SKIP_DIRS = new Set(['.git', '.claude', 'node_modules', 'assets', 'data', 'scripts']);
const SKIP_FILES = new Set(['index.html']);

const NS_RE = /(const\s+NS\s*=\s*'jobStudy::[^']+::';)/;
const ALREADY_EXPOSED_RE = /window\.NS\s*=\s*NS\s*;/;
const WIDGET_SCRIPT_RE = /assets\/study-widget\.js/;

async function findHtmlFiles(dir, out = []) {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const e of entries) {
    if (e.name.startsWith('.')) continue;
    if (SKIP_DIRS.has(e.name)) continue;
    const full = join(dir, e.name);
    if (e.isDirectory()) await findHtmlFiles(full, out);
    else if (e.isFile() && e.name.endsWith('.html') && !SKIP_FILES.has(e.name)) out.push(full);
  }
  return out;
}

function pageDepth(relPath) {
  // "system-design/00-introduction.html" → 1, "backend/architecture/00-introduction.html" → 2
  return relPath.split('/').length - 1;
}

function widgetTagFor(relPath) {
  const prefix = '../'.repeat(pageDepth(relPath));
  return `<script type="module" src="${prefix}assets/study-widget.js?v=1"></script>`;
}

// 한 파일을 분석. { changed, reasons[], output } 리턴.
function transform(html, relPath) {
  const reasons = [];
  let out = html;
  let changed = false;

  // (1) NS 노출
  const nsMatch = out.match(NS_RE);
  if (!nsMatch) {
    reasons.push('SKIP: NS 선언 패턴을 찾지 못함');
    return { changed: false, reasons, output: out };
  }
  if (!ALREADY_EXPOSED_RE.test(out)) {
    out = out.replace(NS_RE, '$1window.NS=NS;');
    reasons.push('+ window.NS=NS 노출');
    changed = true;
  } else {
    reasons.push('= window.NS 이미 노출됨');
  }

  // (2) widget script 태그
  if (!WIDGET_SCRIPT_RE.test(out)) {
    const tag = widgetTagFor(relPath);
    if (out.includes('</body>')) {
      out = out.replace('</body>', `${tag}\n</body>`);
      reasons.push(`+ widget script 추가 (${tag})`);
      changed = true;
    } else {
      reasons.push('SKIP: </body> 를 찾지 못함');
      return { changed: false, reasons, output: html };
    }
  } else {
    reasons.push('= widget script 이미 있음');
  }

  return { changed, reasons, output: out };
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const explicit = args.filter((a) => !a.startsWith('--'));

  let files;
  if (explicit.length) {
    files = explicit.map((p) => resolve(p));
  } else {
    files = await findHtmlFiles(ROOT);
  }
  files.sort();

  let changedCount = 0;
  for (const abs of files) {
    if (!existsSync(abs)) {
      console.warn(`⚠ ${abs} 없음, 건너뜀`);
      continue;
    }
    const rel = relative(ROOT, abs).split(sep).join('/');
    const html = await readFile(abs, 'utf8');
    const { changed, reasons, output } = transform(html, rel);
    const tag = changed ? (dryRun ? '[DRY] WOULD-CHANGE' : 'CHANGED') : 'unchanged';
    console.log(`${tag.padEnd(20)} ${rel}`);
    for (const r of reasons) console.log(`    ${r}`);
    if (changed && !dryRun) {
      await writeFile(abs, output, 'utf8');
    }
    if (changed) changedCount++;
  }

  console.log(`\n${dryRun ? 'DRY-RUN' : 'APPLY'}: ${changedCount}/${files.length} 파일 ${dryRun ? '변경 예정' : '변경됨'}`);
}

main().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});

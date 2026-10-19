#!/usr/bin/env node
// 학습 페이지에 "코치 피드백" 영역을 주입하는 idempotent 도구.
//
// 추가하는 것:
//   1) <head> 안에 `<link rel="stylesheet" href="<상대경로>/assets/feedback.css">` (없으면)
//   2) 각 q-card 의 .ans-area 다음에 .fb-area 블록 (없으면)
//      - Group A: <textarea id="ans1"> → 새 textarea id="fb1"
//      - Group B: <textarea id="ans-cs-q1" oninput="saveAns('cs-q1',this.value)"> → fb-cs-q1
//   3) </body> 직전에 `<script src="<상대경로>/assets/feedback.js?v=1"></script>` (없으면)
//
// 사용법:
//   node scripts/inject-feedback.mjs --dry-run        # 변경 사항만 출력
//   node scripts/inject-feedback.mjs                   # 실제 적용
//   node scripts/inject-feedback.mjs path/to/file.html # 특정 파일만
//
// 멱등성(idempotency): 이미 fb-area 가 있는 q-card 는 건드리지 않는다. 새로 생긴 q-card 만
// 채워 넣는다.

import { readdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, resolve, sep } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

const SKIP_DIRS = new Set(['.git', '.claude', 'node_modules', 'assets', 'data', 'scripts']);
const SKIP_FILES = new Set(['index.html']);

const FEEDBACK_CSS_RE = /assets\/feedback\.css/;
const FEEDBACK_JS_RE = /assets\/feedback\.js/;

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
  return relPath.split('/').length - 1;
}

function relPrefix(relPath) {
  return '../'.repeat(pageDepth(relPath));
}

// ans textarea id 를 fb id 로 매핑.
//   'ans1'        → 'fb1'
//   'ans-cs-q1'   → 'fb-cs-q1'
//   'ansFoo'      → 'fbFoo'
function ansIdToFbId(ansId) {
  if (ansId.startsWith('ans')) return 'fb' + ansId.slice(3);
  return 'fb-' + ansId;
}

// oninput="saveAns('cs-q1',this.value)" → saveAns 의 첫 인자를 fb-cs-q1 으로 바꾼다.
function buildFbOninput(ansOninput, fbId) {
  if (!ansOninput) return null;
  // saveAns('<key>', ...) 패턴이면 그 key 만 교체
  const m = ansOninput.match(/saveAns\(\s*['"]([^'"]+)['"]/);
  if (!m) return null;
  // Group B: ans-cs-q1 의 saveAns 키는 'cs-q1' — fb 측은 'fb-cs-q1' 가 되도록
  return `saveAns('${fbId}',this.value)`;
}

// 한 q-card HTML 조각을 분석하여 fb-area 가 없으면 추가.
// q-card 안에는 정확히 1개의 ans-area 가 있다는 가정.
function injectFbIntoCard(cardHtml) {
  // 이미 fb-area 가 있으면 그대로
  if (/class="fb-area"/.test(cardHtml)) return { card: cardHtml, changed: false };

  // ans textarea 추출
  const taMatch = cardHtml.match(/<textarea\s+([^>]*?)id="(ans[^"]*)"([^>]*)><\/textarea>/);
  if (!taMatch) return { card: cardHtml, changed: false };
  const ansId = taMatch[2];
  const before = taMatch[1] || '';
  const after = taMatch[3] || '';
  const allAttrs = before + after;
  const oninputMatch = allAttrs.match(/oninput="([^"]+)"/);
  const ansOninput = oninputMatch ? oninputMatch[1] : null;

  const fbId = ansIdToFbId(ansId);
  const fbOninput = buildFbOninput(ansOninput, fbId);
  const fbOninputAttr = fbOninput ? ` oninput="${fbOninput}"` : '';

  // </div> 두 개: ans-area 닫는 </div> 와 q-card 닫는 </div>.
  // ans-area 는 항상 q-card 마지막 자식이라 가정 (현 구조 일관됨).
  // .ans-area 의 닫는 태그 위치를 찾아 그 뒤에 fb-area 삽입.
  const ansAreaCloseRe = /(<div\s+class="ans-area">[\s\S]*?<\/textarea>\s*<\/div>)/;
  const ansAreaMatch = cardHtml.match(ansAreaCloseRe);
  if (!ansAreaMatch) return { card: cardHtml, changed: false };

  const fbBlock = `
      <div class="fb-area">
        <div class="fb-label">
          <span class="fb-title">🎓 코치 피드백 <span style="font-weight:400;color:#a16207;font-size:11px">(마크다운 지원)</span></span>
          <span class="fb-controls">
            <button type="button" class="fb-toggle" data-fb-target="${fbId}">미리보기</button>
            <span class="fb-saved-badge">저장됨 ✓</span>
          </span>
        </div>
        <textarea id="${fbId}"${fbOninputAttr} placeholder="코치에게 받은 피드백을 붙여넣으세요... (자동 저장)"></textarea>
        <div class="fb-preview" id="preview-${fbId}" hidden></div>
      </div>`;

  const newCard = cardHtml.replace(ansAreaCloseRe, `$1${fbBlock}`);
  return { card: newCard, changed: true };
}

// 한 파일 전체 transform.
function transform(html, relPath) {
  const reasons = [];
  let out = html;
  let changed = false;
  const prefix = relPrefix(relPath);

  // (1) feedback.css link
  if (!FEEDBACK_CSS_RE.test(out)) {
    const tag = `<link rel="stylesheet" href="${prefix}assets/feedback.css?v=1">`;
    if (out.includes('</head>')) {
      out = out.replace('</head>', `${tag}\n</head>`);
      reasons.push(`+ feedback.css link 추가`);
      changed = true;
    } else {
      reasons.push('SKIP: </head> 를 찾지 못함');
      return { changed: false, reasons, output: html };
    }
  } else {
    reasons.push('= feedback.css 이미 있음');
  }

  // (2) q-card 들을 순회하면서 fb-area 가 없는 것에 주입.
  // 각 q-card 블록은 비-nesting 패턴이라 단순 정규식으로 잘라낸다.
  const cardRe = /<div\s+class="q-card"[^>]*>[\s\S]*?<\/div>\s*<\/div>/g;
  let injectedCount = 0;
  let skippedNoTextarea = 0;
  out = out.replace(cardRe, (cardHtml) => {
    const { card, changed: cChanged } = injectFbIntoCard(cardHtml);
    if (cChanged) {
      injectedCount++;
      return card;
    }
    if (!/<textarea/.test(cardHtml)) skippedNoTextarea++;
    return cardHtml;
  });
  if (injectedCount > 0) {
    reasons.push(`+ fb-area 주입: ${injectedCount}개 q-card`);
    changed = true;
  } else {
    reasons.push(`= fb-area 모두 이미 있음 또는 q-card 없음`);
  }

  // (3) feedback.js script
  if (!FEEDBACK_JS_RE.test(out)) {
    const tag = `<script src="${prefix}assets/feedback.js?v=1"></script>`;
    if (out.includes('</body>')) {
      out = out.replace('</body>', `${tag}\n</body>`);
      reasons.push(`+ feedback.js script 추가`);
      changed = true;
    } else {
      reasons.push('SKIP: </body> 를 찾지 못함');
      return { changed: false, reasons, output: html };
    }
  } else {
    reasons.push('= feedback.js 이미 있음');
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

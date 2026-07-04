#!/usr/bin/env node
// 브라우저에서 다운로드한 jobstudy-{qa,progress,full}-export-*.json 파일을
// data/qa-history.json (Q&A) 와 data/progress-history.json (진도) 에 머지·정렬해 저장.
//
// Usage:
//   node scripts/export-qa.mjs ~/Downloads/jobstudy-qa-export-2026-04-25.json
//   node scripts/export-qa.mjs ~/Downloads/jobstudy-full-export-2026-04-25.json
//
// 동일 키는 incoming(브라우저 export)이 우선.

import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');

async function loadJsonOr(path, fallback) {
  if (!existsSync(path)) return fallback;
  try {
    return JSON.parse(await readFile(path, 'utf8'));
  } catch (err) {
    console.warn(`⚠️  ${path} 파싱 실패: ${err.message} — 기본값 사용`);
    return fallback;
  }
}

function sortKeys(obj) {
  if (!obj) return obj;
  const sorted = {};
  for (const k of Object.keys(obj).sort()) sorted[k] = obj[k];
  return sorted;
}

async function mergeQa(incoming) {
  const path = join(ROOT, 'data', 'qa-history.json');
  const existing = await loadJsonOr(path, { version: 1, answers: {} });
  const merged = { ...existing.answers, ...incoming.answers };
  const out = {
    version: 1,
    updatedAt: new Date().toISOString(),
    answerCount: Object.keys(merged).length,
    answers: sortKeys(merged),
  };
  await writeFile(path, JSON.stringify(out, null, 2) + '\n', 'utf8');
  return out.answerCount;
}

async function mergeProgress(incoming) {
  const path = join(ROOT, 'data', 'progress-history.json');
  const existing = await loadJsonOr(path, { version: 1, progress: {} });
  // 진도는 record 별로 lastVisitedAt 늦은 쪽 우선
  const merged = { ...existing.progress };
  for (const [id, rec] of Object.entries(incoming.progress)) {
    const old = merged[id];
    if (!old) { merged[id] = rec; continue; }
    const oldT = Date.parse(old.lastVisitedAt || 0) || 0;
    const newT = Date.parse(rec.lastVisitedAt || 0) || 0;
    merged[id] = newT >= oldT ? rec : old;
  }
  const out = {
    version: 1,
    updatedAt: new Date().toISOString(),
    recordCount: Object.keys(merged).length,
    progress: sortKeys(merged),
  };
  await writeFile(path, JSON.stringify(out, null, 2) + '\n', 'utf8');
  return out.recordCount;
}

async function main() {
  const inputPath = process.argv[2];
  if (!inputPath) {
    console.error('Usage: node scripts/export-qa.mjs <browser-export.json>');
    process.exit(1);
  }
  const inputAbs = resolve(process.cwd(), inputPath);
  if (!existsSync(inputAbs)) {
    console.error(`❌ 파일이 없습니다: ${inputAbs}`);
    process.exit(1);
  }
  const incoming = JSON.parse(await readFile(inputAbs, 'utf8'));

  const reports = [];
  if (incoming.answers && Object.keys(incoming.answers).length) {
    const n = await mergeQa({ answers: incoming.answers });
    reports.push(`Q&A → data/qa-history.json (총 ${n}건)`);
  }
  if (incoming.progress && Object.keys(incoming.progress).length) {
    const n = await mergeProgress({ progress: incoming.progress });
    reports.push(`진도 → data/progress-history.json (총 ${n}건)`);
  }
  if (!reports.length) {
    console.warn('⚠️  처리할 데이터가 없습니다 (answers/progress 키 없음)');
    process.exit(2);
  }
  console.log('✅ 머지 완료:');
  for (const r of reports) console.log('   - ' + r);
  console.log('💡 Git 커밋 권장: git add data/ && git commit -m "chore: backup study state"');
}

main().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});

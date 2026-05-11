// jobStudy Q&A 통합 관리 모듈
// localStorage 의 jobStudy::*::ans*  키들을 콘텐츠별로 그룹핑한다.
// 옵션 B: GitHub `answers/<pagePath>.json` (qna-sync.js → Cloudflare Worker가 저장)
//   을 read-only로 prefetch해 cloud 답변과 병합. cloud 우선, 없으면 localStorage fallback.

// pagePath cache: pagePath -> { answers, updatedAt } | null (404 또는 fetch 실패 시 null)
const cloudCache = new Map();
let cloudPrefetchedAt = null;

// fetch 가 hang 하면 init 의 await 가 멈춰 인덱스 첫 렌더가 미뤄진다. 5초 timeout 으로 차단.
const PREFETCH_TIMEOUT_MS = 5000;

function pagePathFromNs(ns) {
  if (!ns) return null;
  return ns.replace(/^jobStudy::/, '').replace(/::$/, '').replace(/::/g, '/');
}

// 다음 prefetch 가 stale 한 답을 보지 않도록 cache 비우기. JSON import 직후 호출.
export function invalidateCloudCache() {
  cloudCache.clear();
  cloudPrefetchedAt = null;
}

// 인덱스 페이지 init 시 1회 호출. 모든 콘텐츠의 cloud 답변을 병렬 fetch.
// import 후 재호출 시는 invalidateCloudCache() 먼저 부르거나 그냥 재호출만 해도
// 같은 key 에 새 값이 덮여진다.
export async function prefetchCloud(contents) {
  const targets = contents
    .filter((c) => c.qaNs)
    .map((c) => pagePathFromNs(c.qaNs))
    .filter(Boolean);

  await Promise.all(
    targets.map(async (pagePath) => {
      const ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const timer = ctrl ? setTimeout(() => ctrl.abort(), PREFETCH_TIMEOUT_MS) : null;
      try {
        const r = await fetch(`./answers/${pagePath}.json`, {
          cache: 'no-store',
          signal: ctrl?.signal,
        });
        if (r.ok) {
          const data = await r.json();
          cloudCache.set(pagePath, data);
        } else if (r.status !== 404) {
          // 404 는 "아직 답변 없음" — 정상 시나리오. 그 외 응답은 디버깅용 로그.
          console.warn(`[qa-aggregator] cloud fetch ${pagePath} → HTTP ${r.status}`);
          cloudCache.set(pagePath, null);
        } else {
          cloudCache.set(pagePath, null);
        }
      } catch (err) {
        const isAbort = err?.name === 'AbortError';
        console.warn(
          `[qa-aggregator] cloud fetch ${pagePath} ${isAbort ? `시간초과(${PREFETCH_TIMEOUT_MS}ms)` : '실패'}:`,
          err?.message || err
        );
        cloudCache.set(pagePath, null);
      } finally {
        if (timer) clearTimeout(timer);
      }
    })
  );
  cloudPrefetchedAt = new Date().toISOString();
  return cloudCache;
}

// content 에 대응되는 cloud 답변 dict (없으면 null)
export function getCloudAnswers(content) {
  const pagePath = pagePathFromNs(content.qaNs);
  if (!pagePath) return null;
  const c = cloudCache.get(pagePath);
  return c && typeof c.answers === 'object' ? c.answers : null;
}

// content 에 대응되는 cloud 코치 피드백 dict (없으면 null)
export function getCloudFeedbacks(content) {
  const pagePath = pagePathFromNs(content.qaNs);
  if (!pagePath) return null;
  const c = cloudCache.get(pagePath);
  return c && typeof c.feedbacks === 'object' ? c.feedbacks : null;
}

// cloud 통계 — KPI/표시용
export function cloudStats(contents) {
  let pages = 0;
  let answers = 0;
  let latest = null;
  for (const c of contents) {
    const pagePath = pagePathFromNs(c.qaNs);
    if (!pagePath) continue;
    const entry = cloudCache.get(pagePath);
    if (!entry || typeof entry.answers !== 'object') continue;
    const filled = Object.values(entry.answers).filter((v) => v && String(v).trim()).length;
    if (filled > 0) {
      pages++;
      answers += filled;
    }
    if (entry.updatedAt && (!latest || entry.updatedAt > latest)) latest = entry.updatedAt;
  }
  return { pages, answers, latest, prefetchedAt: cloudPrefetchedAt };
}

// 콘텐츠 메타에서 NS 와 ansIds 를 받아 답변 dict 를 만든다.
// 정책:
//   1. cloud 답변이 비어 있으면 localStorage 사용
//   2. localStorage 답변이 비어 있으면 cloud 사용
//   3. 둘 다 있고 값이 다르면 — 더 긴 쪽을 사용자의 더 최신 입력으로 간주.
//      (qna-sync 가 오프라인이거나 push 실패 후 사용자가 추가 입력한 시나리오를 보호)
//      divergence 발생 시 console.warn 으로 추적 가능하게 한다.
export function readAnswersFor(content) {
  return mergeCloudLocal(content, content.qaIds || [], getCloudAnswers(content) || {});
}

// ans suffix(예: 'ans1', 'cs-q1')를 fb suffix(예: 'fb1', 'fb-cs-q1')로 매핑.
// Group A: 'ans1' → 'fb1' (prefix 교체)
// Group B: 'cs-q1' → 'fb-cs-q1' (suffix 자체가 ans- 가 없는 형태이므로 'fb-' 접두)
//   ※ extractAnsIds 가 'ans-cs-q1' 에서 'cs-q1' 만 남겨두기 때문에, 이 경우 fb 키는
//      'fb-cs-q1' (textarea id 와 동일). qna-sync 가 textarea id 그대로 키로 push 함.
function ansSuffixToFbSuffix(ansSuffix) {
  if (ansSuffix.startsWith('ans')) {
    // 'ans1' → 'fb1', 'ans-foo' → 'fb-foo'
    return 'fb' + ansSuffix.slice(3);
  }
  // 'cs-q1' → 'fb-cs-q1' (Group B 의 normalized suffix)
  return 'fb-' + ansSuffix;
}

// 코치 피드백 dict — ans suffix 와 1:1 매핑된 fb suffix 키로 반환.
// out['ans1'] = "코치 피드백 텍스트"  (키는 ansSuffix 그대로 — UI 매핑 편의)
export function readFeedbacksFor(content) {
  if (!content.qaNs) return {};
  const cloud = getCloudFeedbacks(content) || {};
  const fbSuffixes = (content.qaIds || []).map(ansSuffixToFbSuffix);
  const merged = mergeCloudLocal(content, fbSuffixes, cloud);
  // 결과 키를 ansSuffix 기준으로 재매핑 (UI 에서 답변과 짝지을 때 편함)
  const out = {};
  (content.qaIds || []).forEach((ansSuffix, i) => {
    const fbSuffix = fbSuffixes[i];
    if (merged[fbSuffix] != null) out[ansSuffix] = merged[fbSuffix];
  });
  return out;
}

// cloud dict + localStorage 를 같은 정책으로 merge — answers/feedbacks 둘 다에서 재사용.
function mergeCloudLocal(content, suffixes, cloud) {
  const out = {};
  for (const suffix of suffixes) {
    const cloudRaw = cloud[suffix];
    const localRaw = localStorage.getItem(content.qaNs + suffix);
    const cloudStr = cloudRaw != null && String(cloudRaw).trim() ? String(cloudRaw) : null;
    const localStr = localRaw != null && String(localRaw).trim() ? String(localRaw) : null;

    if (cloudStr != null && localStr != null && cloudStr !== localStr) {
      const cloudLen = cloudStr.trim().length;
      const localLen = localStr.trim().length;
      if (localLen > cloudLen) {
        console.warn(
          `[qa-aggregator] ${content.qaNs}${suffix} divergence: local(${localLen}) > cloud(${cloudLen}) — using local`
        );
        out[suffix] = localStr;
        continue;
      }
    }
    if (cloudStr != null) { out[suffix] = cloudStr; continue; }
    if (localRaw != null) out[suffix] = localRaw;
  }
  return out;
}

// 모든 콘텐츠에 대해 그룹핑된 답변 + 코치 피드백 + 메타
export function aggregate(contents) {
  return contents
    .map((c) => {
      const answers = readAnswersFor(c);
      const feedbacks = readFeedbacksFor(c);
      const total = c.qaCount || 0;
      const answered = Object.values(answers).filter((v) => v && v.trim().length > 0).length;
      const feedbackCount = Object.values(feedbacks).filter((v) => v && v.trim().length > 0).length;
      return {
        id: c.id,
        path: c.path,
        title: c.title,
        coach: c.coach,
        area: c.area,
        ns: c.qaNs,
        ids: c.qaIds || [],
        questions: c.qaQuestions || [],
        answers,
        feedbacks,
        total,
        answered,
        feedbackCount,
      };
    })
    .filter((g) => g.total > 0);
}

// localStorage 전체 스캔 — 메타에 없는 키도 잡아낸다 (오래된 답변 보존용)
export function scanOrphanAnswers(knownNamespaces) {
  const known = new Set(knownNamespaces.filter(Boolean));
  const orphan = [];
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key || !key.startsWith('jobStudy::')) continue;
    if (key.startsWith('jobStudy::progress::')) continue;
    // 알려진 NS prefix 중 어느 것에도 속하지 않으면 orphan
    if (![...known].some((ns) => key.startsWith(ns))) {
      orphan.push({ key, value: localStorage.getItem(key) });
    }
  }
  return orphan;
}

// 사람-읽기 텍스트 (기존 copyForFeedback 형식 유지)
// 코치 피드백이 이미 있으면 함께 표시 → "재피드백" 또는 비교 요청 시 유용.
export function formatForFeedback(group) {
  const lines = [`[${group.title || group.path} — Q&A 피드백 요청]`, ''];
  group.ids.forEach((suffix, i) => {
    const q = group.questions[i] || '(질문 추출 실패)';
    const a = (group.answers[suffix] || '').trim();
    const fb = (group.feedbacks && group.feedbacks[suffix] || '').trim();
    lines.push(`Q${i + 1}. ${q}`);
    lines.push(`내 답변: ${a || '(미작성)'}`);
    if (fb) {
      lines.push(`기존 코치 피드백:`);
      lines.push(fb);
    }
    lines.push('');
  });
  lines.push(`위 답변들에 대해 ${group.coach || '시니어 코치'} 관점에서 피드백 부탁드립니다.`);
  return lines.join('\n');
}

export function formatAllForFeedback(groups) {
  return groups
    .filter((g) => g.answered > 0)
    .map(formatForFeedback)
    .join('\n\n──────────\n\n');
}

// JSON export — 키별 dict
export function exportSnapshot(contents) {
  const groups = aggregate(contents);
  const out = {
    version: 1,
    exportedAt: new Date().toISOString(),
    answers: {},
  };
  for (const g of groups) {
    for (const suffix of g.ids) {
      const v = g.answers[suffix];
      if (v != null) out.answers[g.ns + suffix] = v;
    }
  }
  // orphan 도 포함
  const orphans = scanOrphanAnswers(contents.map((c) => c.qaNs));
  for (const o of orphans) out.answers[o.key] = o.value;
  return out;
}

// JSON import — 키별 dict 를 localStorage 에 쓰기
export function importSnapshot(snapshot, opts = {}) {
  if (!snapshot || typeof snapshot.answers !== 'object') {
    throw new Error('snapshot.answers 가 객체가 아님');
  }
  const overwrite = opts.overwrite ?? true;
  let written = 0;
  let skipped = 0;
  for (const [key, val] of Object.entries(snapshot.answers)) {
    if (!key.startsWith('jobStudy::') || key.startsWith('jobStudy::progress::')) {
      skipped++; continue;
    }
    const existing = localStorage.getItem(key);
    if (existing != null && !overwrite) { skipped++; continue; }
    localStorage.setItem(key, val);
    written++;
  }
  return { written, skipped };
}

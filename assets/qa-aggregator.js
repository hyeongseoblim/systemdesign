// jobStudy Q&A 통합 관리 모듈
// localStorage 의 jobStudy::*::ans*  키들을 콘텐츠별로 그룹핑한다.
// 옵션 B: GitHub `answers/<pagePath>.json` (qna-sync.js → Cloudflare Worker가 저장)
//   을 read-only로 prefetch해 cloud 답변과 병합. cloud 우선, 없으면 localStorage fallback.

// pagePath cache: pagePath -> { answers, updatedAt } | null (404 또는 fetch 실패 시 null)
const cloudCache = new Map();
let cloudPrefetchedAt = null;

function pagePathFromNs(ns) {
  if (!ns) return null;
  return ns.replace(/^jobStudy::/, '').replace(/::$/, '').replace(/::/g, '/');
}

// 인덱스 페이지 init 시 1회 호출. 모든 콘텐츠의 cloud 답변을 병렬 fetch.
export async function prefetchCloud(contents) {
  const targets = contents
    .filter((c) => c.qaNs)
    .map((c) => pagePathFromNs(c.qaNs))
    .filter(Boolean);

  await Promise.all(
    targets.map(async (pagePath) => {
      try {
        const r = await fetch(`./answers/${pagePath}.json`, { cache: 'no-store' });
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
        console.warn(`[qa-aggregator] cloud fetch ${pagePath} 실패:`, err?.message || err);
        cloudCache.set(pagePath, null);
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
  const out = {};
  if (!content.qaNs) return out;
  const cloud = getCloudAnswers(content) || {};
  for (const suffix of content.qaIds || []) {
    const cloudRaw = cloud[suffix];
    const localRaw = localStorage.getItem(content.qaNs + suffix);
    const cloudStr = cloudRaw != null && String(cloudRaw).trim() ? String(cloudRaw) : null;
    const localStr = localRaw != null && String(localRaw).trim() ? String(localRaw) : null;

    if (cloudStr != null && localStr != null && cloudStr !== localStr) {
      // divergence — 길이 비교로 우선순위 결정
      const cloudLen = cloudStr.trim().length;
      const localLen = localStr.trim().length;
      if (localLen > cloudLen) {
        console.warn(
          `[qa-aggregator] ${content.qaNs}${suffix} divergence: local(${localLen}) > cloud(${cloudLen}) — using local`
        );
        out[suffix] = localStr;
        continue;
      }
      // cloud 가 같거나 더 길면 cloud 사용 (default)
    }
    if (cloudStr != null) { out[suffix] = cloudStr; continue; }
    if (localRaw != null) out[suffix] = localRaw;
  }
  return out;
}

// 모든 콘텐츠에 대해 그룹핑된 답변 + 메타
export function aggregate(contents) {
  return contents
    .map((c) => {
      const answers = readAnswersFor(c);
      const total = c.qaCount || 0;
      const answered = Object.values(answers).filter((v) => v && v.trim().length > 0).length;
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
        total,
        answered,
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
export function formatForFeedback(group) {
  const lines = [`[${group.title || group.path} — Q&A 피드백 요청]`, ''];
  group.ids.forEach((suffix, i) => {
    const q = group.questions[i] || '(질문 추출 실패)';
    const a = (group.answers[suffix] || '').trim();
    lines.push(`Q${i + 1}. ${q}`);
    lines.push(`내 답변: ${a || '(미작성)'}`);
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

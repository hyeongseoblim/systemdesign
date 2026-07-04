// HTML 학습 산출물에서 메타데이터를 추출한다.
// expanded(logistics) / minified(나머지) 양쪽 변형을 모두 매칭한다.

const COACH_NAMES = [
  'system-design-coach',
  'logistics-domain-coach',
  'backend-architecture-coach',
  'backend-dev-coach',
  'database-coach',
  'infra-coach',
  'cs-fundamentals-coach',
];

const MODE_PATTERNS = [
  { re: /Concept\s*모드|Concept\s*Mode/i, mode: 'concept' },
  { re: /Design\s*모드|Design\s*Mode/i, mode: 'design' },
  { re: /Interview\s*모드|Interview\s*Mode/i, mode: 'interview' },
  { re: /Review\s*모드|Review\s*Mode/i, mode: 'review' },
];

function decodeEntities(s) {
  if (!s) return s;
  return s
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ');
}

function extractTitle(html) {
  const m = html.match(/<title>([\s\S]*?)<\/title>/i);
  return m ? decodeEntities(m[1].trim()) : null;
}

function extractChips(html) {
  const block = html.match(/<div\s+class="chips"[^>]*>([\s\S]*?)<\/div>/i);
  if (!block) return [];
  return [...block[1].matchAll(/<span[^>]*class="chip[^"]*"[^>]*>([\s\S]*?)<\/span>/gi)]
    .map((m) => decodeEntities(m[1].replace(/\s+/g, ' ').trim()));
}

function extractCoach(chips) {
  for (const c of chips) {
    const found = COACH_NAMES.find((name) => c.includes(name));
    if (found) return found;
  }
  return null;
}

function extractMode(chips) {
  const joined = chips.join(' | ');
  for (const { re, mode } of MODE_PATTERNS) {
    if (re.test(joined)) return mode;
  }
  return null;
}

function extractDate(chips) {
  for (const c of chips) {
    const m = c.match(/(\d{4}-\d{2}-\d{2})/);
    if (m) return m[1];
  }
  return null;
}

function extractSession(chips) {
  for (const c of chips) {
    const m = c.match(/Session\s*#\d+[^|]*/i);
    if (m) return m[0].trim();
  }
  return null;
}

function extractAnsIds(html) {
  // 두 변형 모두 지원:
  //   A) <textarea id="ans1">  → key suffix = "ans1"
  //   B) <textarea id="ans-db-q1"> + saveAns('db-q1', ...) → key suffix = "db-q1"
  //
  // localStorage 키 = NS + suffix. 인덱스는 이 suffix를 알아야 답변을 스캔할 수 있다.
  const ids = [...html.matchAll(/<textarea[^>]*\sid="([^"]+)"/gi)].map((m) => m[1]);
  const suffixes = ids
    .filter((id) => id === 'ans' || id.startsWith('ans') || id.startsWith('ans-'))
    .map((id) => (id.startsWith('ans-') ? id.slice(4) : id));
  // 중복 제거 + 입력 순서 유지
  return [...new Set(suffixes)];
}

function extractQuestions(html) {
  // 우선순위:
  //   1) const questions = [ '...', '...' ];  (Group A: logistics 등)
  //   2) <div class="q-card"> ... <p>...</p> ... </div>  (Group B: database/cs/infra)
  const block = html.match(/const\s+questions\s*=\s*\[([\s\S]*?)\]\s*;/);
  if (block) {
    return [...block[1].matchAll(/'([^']*)'|"([^"]*)"/g)].map((m) => decodeEntities(m[1] ?? m[2]));
  }
  const cards = [...html.matchAll(/<div[^>]*class="q-card"[^>]*>([\s\S]*?)<\/div>/gi)];
  if (cards.length === 0) return [];
  return cards
    .map((m) => {
      const inner = m[1];
      const p = inner.match(/<p[^>]*>([\s\S]*?)<\/p>/i);
      if (!p) return null;
      return decodeEntities(p[1].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim());
    })
    .filter(Boolean);
}

function extractNs(html) {
  // const NS = 'jobStudy::<...>::'  (각 HTML이 자기 namespace를 직접 정의)
  const m = html.match(/const\s+NS\s*=\s*['"]([^'"]+)['"]/);
  return m ? m[1] : null;
}

function extractH1(html) {
  const m = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  return m ? decodeEntities(m[1].replace(/<[^>]+>/g, '').trim()) : null;
}

function pathToId(relPath) {
  return relPath.replace(/\.html$/, '').replace(/\\/g, '/');
}

function pathToArea(relPath) {
  // 첫 번째 디렉토리 = 영역.
  // backend/architecture/* 는 'backend/architecture' 로 한 단계 더.
  const parts = relPath.split('/');
  if (parts.length >= 3 && parts[0] === 'backend' && parts[1] === 'architecture') {
    return 'backend/architecture';
  }
  return parts[0];
}

export function parseMeta(html, relPath) {
  const chips = extractChips(html);
  const ansIds = extractAnsIds(html);
  const questions = extractQuestions(html);
  return {
    id: pathToId(relPath),
    path: relPath,
    area: pathToArea(relPath),
    title: extractTitle(html) || extractH1(html),
    h1: extractH1(html),
    coach: extractCoach(chips),
    mode: extractMode(chips),
    sessionLabel: extractSession(chips),
    createdAt: extractDate(chips),
    chips,
    qaCount: ansIds.length,
    qaIds: ansIds,
    qaQuestions: questions,
    qaNs: extractNs(html),
  };
}

export const _internal = {
  decodeEntities,
  extractTitle,
  extractChips,
  extractCoach,
  extractMode,
  extractDate,
  extractSession,
  extractAnsIds,
  extractQuestions,
  extractNs,
  extractH1,
  pathToId,
  pathToArea,
};

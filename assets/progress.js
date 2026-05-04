// jobStudy 학습 진도 + SRS 모듈
// localStorage 키:
//   jobStudy::progress::<id>                   — 메인 record
//   jobStudy::dwell-delta::<id>::<tabId>       — 탭별 dwell pending (race-free)

const NS = 'jobStudy::progress::';
const DWELL_DELTA_NS = 'jobStudy::dwell-delta::';
const TAB_KEY = 'jobStudy::tab-id';
const SRS_STAGES_DAYS = [1, 3, 7, 14, 30, 60];

// 같은 페이지를 여러 탭에 열어두면 두 탭이 동시에 main record 의 dwellMs 를
// read-modify-write 해서 lost update 가 날 수 있다. 이를 피하려고 각 탭은
// 자기 dwell 누적을 별도 키(`dwell-delta::<id>::<tabId>`)에 쓴다.
// `get(id)` 호출 시 모든 탭의 delta 를 main record 에 흡수하므로 dashboard 도
// 항상 최신 합계를 본다. 흡수 자체에 race 가 남아 있지만 (drop window 가 매우 짧음
// 단일 read-modify-write), 실 사용에서 의미 있는 손실은 거의 없다.
function getTabId() {
  if (typeof sessionStorage === 'undefined') return 'no-session';
  let id = sessionStorage.getItem(TAB_KEY);
  if (!id) {
    id = 't' + Math.random().toString(36).slice(2, 10);
    sessionStorage.setItem(TAB_KEY, id);
  }
  return id;
}

// 모든 탭의 pending dwell 을 main record 에 흡수. delta 키가 없으면 noop.
// 두 탭이 거의 동시에 흡수를 시도해도 read+remove 를 한 짝으로 처리해서
// race window 를 좁힌다. (완전 atomic 은 아니지만 dwellMs 는 정보성 metric 이라 ok.)
function absorbDwellDeltas(id) {
  const prefix = DWELL_DELTA_NS + id + '::';
  const keys = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k && k.startsWith(prefix)) keys.push(k);
  }
  if (keys.length === 0) return;
  let total = 0;
  for (const k of keys) {
    const v = parseInt(localStorage.getItem(k) || '0', 10) || 0;
    // 다른 탭이 같은 키를 동시에 읽었더라도 즉시 제거하면 다음 read 는 null → 중복 흡수 차단.
    localStorage.removeItem(k);
    if (v > 0) total += v;
  }
  if (total === 0) return;
  const raw = localStorage.getItem(NS + id);
  let rec = newRecord();
  if (raw) {
    try { rec = JSON.parse(raw); } catch {}
  }
  if (!rec.srs) rec.srs = newRecord().srs;
  if (typeof rec.dwellMs !== 'number') rec.dwellMs = 0;
  rec.dwellMs += total;
  localStorage.setItem(NS + id, JSON.stringify(rec));
}

const STATUS = {
  NOT_STARTED: 'not_started',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  REVIEW_NEEDED: 'review_needed',
};

const STATUS_LABEL = {
  not_started: '미시작',
  in_progress: '진행 중',
  completed: '완료',
  review_needed: '복습 필요',
};

function nowIso() { return new Date().toISOString(); }
function todayDate() {
  const d = new Date();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).toISOString();
}
function addDaysIso(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString();
}

function newRecord() {
  return {
    status: STATUS.NOT_STARTED,
    firstVisitedAt: null,
    lastVisitedAt: null,
    visitCount: 0,
    dwellMs: 0,
    completedAt: null,
    srs: {
      stage: 0,
      nextDueAt: null,
      lastReviewedAt: null,
      snoozedUntil: null,
    },
  };
}

export function get(id) {
  // 다른 탭에서 누적된 dwell pending 을 먼저 main 으로 흡수.
  absorbDwellDeltas(id);
  const raw = localStorage.getItem(NS + id);
  if (!raw) return newRecord();
  try {
    const obj = JSON.parse(raw);
    // 마이그레이션 보호: 누락 필드 기본값
    if (!obj.srs) obj.srs = newRecord().srs;
    if (typeof obj.dwellMs !== 'number') obj.dwellMs = 0;
    return obj;
  } catch {
    return newRecord();
  }
}

export function set(id, record) {
  localStorage.setItem(NS + id, JSON.stringify(record));
}

export function recordVisit(id) {
  const rec = get(id);
  const now = nowIso();
  if (!rec.firstVisitedAt) rec.firstVisitedAt = now;
  rec.lastVisitedAt = now;
  rec.visitCount = (rec.visitCount || 0) + 1;
  if (rec.status === STATUS.NOT_STARTED) rec.status = STATUS.IN_PROGRESS;
  set(id, rec);
  return rec;
}

// 학습 페이지 활성 시간 누적 (ms 단위). 위젯이 visibilitychange/beforeunload 에서 호출.
// 1초 미만이면 노이즈로 간주, 6시간 초과면 비정상으로 간주(자다 깨어나서 발생) → 무시.
// 자기 탭의 delta 키에만 쓰므로 다른 탭의 addDwell 과 충돌 없음. 합산은 다음 get() 에서.
export function addDwell(id, ms) {
  if (!ms || ms < 1000 || ms > 6 * 60 * 60 * 1000) return null;
  const key = DWELL_DELTA_NS + id + '::' + getTabId();
  const cur = parseInt(localStorage.getItem(key) || '0', 10) || 0;
  localStorage.setItem(key, String(cur + ms));
  return null;
}

// dwell 포맷 — "12분", "1시간 23분"
export function formatDwell(ms) {
  if (!ms || ms < 60 * 1000) return '< 1분';
  const totalMin = Math.floor(ms / 60000);
  if (totalMin < 60) return `${totalMin}분`;
  const hr = Math.floor(totalMin / 60);
  const min = totalMin % 60;
  return min ? `${hr}시간 ${min}분` : `${hr}시간`;
}

export function markCompleted(id) {
  const rec = get(id);
  rec.status = STATUS.COMPLETED;
  rec.completedAt = nowIso();
  // SRS 시작
  rec.srs.stage = 0;
  rec.srs.lastReviewedAt = nowIso();
  rec.srs.nextDueAt = addDaysIso(SRS_STAGES_DAYS[0]);
  rec.srs.snoozedUntil = null;
  set(id, rec);
  return rec;
}

export function unmarkCompleted(id) {
  const rec = get(id);
  rec.status = rec.visitCount > 0 ? STATUS.IN_PROGRESS : STATUS.NOT_STARTED;
  rec.completedAt = null;
  rec.srs = newRecord().srs;
  set(id, rec);
  return rec;
}

export function reviewSuccess(id) {
  const rec = get(id);
  if (rec.status !== STATUS.COMPLETED && rec.status !== STATUS.REVIEW_NEEDED) {
    return rec;
  }
  rec.srs.stage = Math.min(rec.srs.stage + 1, SRS_STAGES_DAYS.length - 1);
  rec.srs.lastReviewedAt = nowIso();
  rec.srs.nextDueAt = addDaysIso(SRS_STAGES_DAYS[rec.srs.stage]);
  rec.srs.snoozedUntil = null;
  rec.status = STATUS.COMPLETED;
  set(id, rec);
  return rec;
}

export function reviewFail(id) {
  const rec = get(id);
  rec.srs.stage = Math.max(rec.srs.stage - 1, 0);
  rec.srs.lastReviewedAt = nowIso();
  rec.srs.nextDueAt = addDaysIso(SRS_STAGES_DAYS[rec.srs.stage]);
  rec.srs.snoozedUntil = null;
  rec.status = STATUS.REVIEW_NEEDED;
  set(id, rec);
  return rec;
}

export function snooze(id, days = 1) {
  const rec = get(id);
  rec.srs.snoozedUntil = addDaysIso(days);
  set(id, rec);
  return rec;
}

export function resetSrs(id) {
  const rec = get(id);
  rec.srs = newRecord().srs;
  set(id, rec);
  return rec;
}

export function clear(id) {
  localStorage.removeItem(NS + id);
}

// 모든 진도 데이터 일괄 조회
export function getAll() {
  const out = {};
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key || !key.startsWith(NS)) continue;
    const id = key.slice(NS.length);
    try { out[id] = JSON.parse(localStorage.getItem(key)); } catch {}
  }
  return out;
}

// 오늘 복습 큐 — nextDueAt 가 지난 것 (snooze 미적용)
export function dueToday(ids) {
  const all = getAll();
  const now = Date.now();
  const due = [];
  for (const id of ids) {
    const rec = all[id];
    if (!rec || !rec.srs?.nextDueAt) continue;
    const dueAt = Date.parse(rec.srs.nextDueAt);
    const snoozedUntil = rec.srs.snoozedUntil ? Date.parse(rec.srs.snoozedUntil) : 0;
    if (dueAt <= now && snoozedUntil <= now) due.push({ id, rec });
  }
  return due.sort((a, b) => Date.parse(a.rec.srs.nextDueAt) - Date.parse(b.rec.srs.nextDueAt));
}

// "n일 전 학습" 같은 인간친화 포맷
export function timeAgo(iso) {
  if (!iso) return '';
  const diff = Date.now() - Date.parse(iso);
  const sec = Math.floor(diff / 1000);
  if (sec < 60) return '방금 전';
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}분 전`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr}시간 전`;
  const day = Math.floor(hr / 24);
  if (day < 30) return `${day}일 전`;
  const month = Math.floor(day / 30);
  if (month < 12) return `${month}개월 전`;
  return `${Math.floor(month / 12)}년 전`;
}

export function dueLabel(rec) {
  if (!rec?.srs?.nextDueAt) return '';
  const diff = Date.parse(rec.srs.nextDueAt) - Date.now();
  if (diff <= 0) return '⏰ 복습 필요';
  const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
  return `⏰ ${days}일 후 복습`;
}

export const _const = { NS, STATUS, STATUS_LABEL, SRS_STAGES_DAYS };

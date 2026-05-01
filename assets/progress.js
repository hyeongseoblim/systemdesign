// jobStudy 학습 진도 + SRS 모듈
// localStorage 키: jobStudy::progress::<id>

const NS = 'jobStudy::progress::';
const SRS_STAGES_DAYS = [1, 3, 7, 14, 30, 60];

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
  const raw = localStorage.getItem(NS + id);
  if (!raw) return newRecord();
  try {
    const obj = JSON.parse(raw);
    // 마이그레이션 보호: srs 누락 시 기본값
    if (!obj.srs) obj.srs = newRecord().srs;
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

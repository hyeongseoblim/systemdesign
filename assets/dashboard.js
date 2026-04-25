// jobStudy 대시보드 — 메인 엔트리.
// data/contents.json 로드 → 필터/검색/정렬/카드 렌더 + 진도/SRS 통합.

import * as progress from './progress.js';
import * as qa from './qa-aggregator.js';

const COACH_TO_AREA_TOKEN = {
  'system-design-coach': 'system-design',
  'logistics-domain-coach': 'logistics',
  'backend-dev-coach': 'backend',
  'backend-architecture-coach': 'backend-architecture',
  'database-coach': 'database',
  'infra-coach': 'infra',
  'cs-fundamentals-coach': 'cs',
};

// 영역(area) 표시명 — area 필드에 슬래시가 들어가는 케이스(backend/architecture) 처리
const AREA_LABEL = {
  'system-design': '시스템 디자인',
  'logistics': '물류 도메인',
  'backend': '백엔드 구현',
  'backend/architecture': '백엔드 아키텍처',
  'database': '데이터베이스',
  'infra': '인프라/DevOps',
  'cs': 'CS 기초',
};

const COACH_LABEL = {
  'system-design-coach': 'System Design',
  'logistics-domain-coach': 'Logistics',
  'backend-dev-coach': 'Backend Dev',
  'backend-architecture-coach': 'Backend Arch',
  'database-coach': 'Database',
  'infra-coach': 'Infra/DevOps',
  'cs-fundamentals-coach': 'CS',
};

const MODE_LABEL = {
  concept: '🎓 Concept',
  design: '🏗 Design',
  interview: '🎤 Interview',
  review: '🔎 Review',
};

// area → CSS color token key (CSS의 --area-* 변수와 매칭)
function areaToColorKey(area) {
  return area.replace(/\//g, '-');
}

// ─────────────────────────  State  ─────────────────────────
const state = {
  contents: [],
  filters: {
    area: new Set(),
    coach: new Set(),
    mode: new Set(),
    difficulty: new Set(),
    status: new Set(),
  },
  search: '',
  sort: 'area',
};

// ─────────────────────────  Data load  ─────────────────────────
async function loadContents() {
  try {
    const res = await fetch('./data/contents.json', { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();
    state.contents = json.contents || [];
    return state.contents;
  } catch (err) {
    document.getElementById('cardGrid').innerHTML =
      `<div class="empty-state"><p>❌ 콘텐츠 인덱스 로드 실패: ${err.message}</p>` +
      `<p class="muted" style="margin-top:8px">로컬 정적 서버로 띄워주세요: <code>python3 -m http.server</code></p></div>`;
    throw err;
  }
}

// ─────────────────────────  Filtering / Sorting  ─────────────────────────
function applyFilters() {
  const q = state.search.trim().toLowerCase();
  const tokens = q ? q.split(/\s+/).filter(Boolean) : [];

  let list = state.contents.filter((c) => {
    if (state.filters.area.size && !state.filters.area.has(c.area)) return false;
    if (state.filters.coach.size && !state.filters.coach.has(c.coach)) return false;
    if (state.filters.mode.size && !state.filters.mode.has(c.mode)) return false;
    if (state.filters.difficulty.size && !state.filters.difficulty.has(c.difficulty ?? 0)) return false;
    if (state.filters.status.size) {
      const rec = progress.get(c.id);
      if (!state.filters.status.has(rec.status)) return false;
    }

    if (tokens.length) {
      const haystack = [
        c.title || '',
        c.h1 || '',
        c.coach || '',
        c.area || '',
        c.description || '',
        ...(c.tags || []),
        ...(c.keywords || []),
        ...(c.qaQuestions || []),
      ].join(' ').toLowerCase();
      for (const t of tokens) {
        if (!haystack.includes(t)) return false;
      }
    }
    return true;
  });

  // 정렬
  switch (state.sort) {
    case 'recent':
      list.sort((a, b) => (b.updatedAt || '').localeCompare(a.updatedAt || ''));
      break;
    case 'difficulty':
      list.sort((a, b) => (a.difficulty ?? 99) - (b.difficulty ?? 99));
      break;
    case 'title':
      list.sort((a, b) => (a.title || '').localeCompare(b.title || '', 'ko'));
      break;
    case 'area':
    default:
      list.sort((a, b) => (a.area || '').localeCompare(b.area || '') || (a.title || '').localeCompare(b.title || '', 'ko'));
  }
  return list;
}

// ─────────────────────────  Renderers  ─────────────────────────
function renderCards(list) {
  const grid = document.getElementById('cardGrid');
  const empty = document.getElementById('emptyState');
  const count = document.getElementById('resultCount');

  count.innerHTML = `<strong>${list.length}</strong> / ${state.contents.length} 항목`;

  if (list.length === 0) {
    grid.innerHTML = '';
    empty.hidden = false;
    return;
  }
  empty.hidden = true;

  grid.innerHTML = list.map(cardHtml).join('');
}

function cardHtml(c) {
  const colorKey = areaToColorKey(c.area || '');
  const accent = `var(--area-${colorKey}, var(--accent))`;
  const accentBg = `var(--area-${colorKey}-bg, #f1f5f9)`;
  const coachLbl = COACH_LABEL[c.coach] || c.coach || 'unknown';
  const modeLbl = MODE_LABEL[c.mode] || (c.mode || '');
  const difficulty = c.difficulty
    ? '●'.repeat(c.difficulty) + '○'.repeat(Math.max(0, 5 - c.difficulty))
    : '— 난이도 미설정';
  const tags = (c.tags || []).slice(0, 4);
  const tagsExtra = Math.max(0, (c.tags || []).length - 4);
  const minutes = c.estimatedMinutes ? `⏱ ${c.estimatedMinutes}분` : '';
  const qaTotal = c.qaCount || 0;
  const updated = c.updatedAt || c.createdAt || '';

  // 진도/SRS 상태
  const rec = progress.get(c.id);
  const status = rec.status;
  const statusBadge = status === progress._const.STATUS.NOT_STARTED ? '' :
    `<span class="status-pill ${escapeAttr(status)}">${escapeHtml(progress._const.STATUS_LABEL[status])}</span>`;
  const pct = status === progress._const.STATUS.COMPLETED ? 100
    : status === progress._const.STATUS.IN_PROGRESS ? 50
    : status === progress._const.STATUS.REVIEW_NEEDED ? 100
    : 0;
  const lastVisitLbl = rec.lastVisitedAt ? `📅 ${progress.timeAgo(rec.lastVisitedAt)} 학습` : (updated ? `📅 ${updated}` : '');
  const dueLbl = progress.dueLabel(rec);
  const isCompleted = status === progress._const.STATUS.COMPLETED || status === progress._const.STATUS.REVIEW_NEEDED;
  const qaAnswered = countAnswered(c);

  return `
    <article class="card" style="--card-accent: ${accent}; --card-accent-bg: ${accentBg};" data-id="${escapeAttr(c.id)}">
      <div class="card-status">
        ${statusBadge}
        <button class="card-action-btn" data-action="toggle-complete" data-id="${escapeAttr(c.id)}" title="${isCompleted ? '완료 해제' : '완료 표시'}">${isCompleted ? '✓' : '○'}</button>
      </div>
      <div class="card-head">
        <span class="badge coach">${escapeHtml(coachLbl)}</span>
        ${c.mode ? `<span class="badge mode ${escapeAttr(c.mode)}">${escapeHtml(modeLbl)}</span>` : ''}
      </div>
      <h2 class="card-title">
        <a href="./${escapeAttr(c.path)}" target="_blank" rel="noopener" data-card-link="${escapeAttr(c.id)}">${escapeHtml(c.title || c.path)}</a>
      </h2>
      ${c.description ? `<p class="muted" style="font-size:12px;margin:0;line-height:1.5">${escapeHtml(c.description)}</p>` : ''}
      ${tags.length ? `<div class="card-tags">${tags.map((t) => `<span class="card-tag">${escapeHtml(t)}</span>`).join('')}${tagsExtra ? `<span class="card-tag" style="background:transparent;border:none">+${tagsExtra}</span>` : ''}</div>` : ''}
      <div class="card-meta">
        <span class="difficulty" title="난이도">${difficulty}</span>
        ${minutes ? `<span class="meta-sep">·</span><span>${minutes}</span>` : ''}
        ${lastVisitLbl ? `<span class="meta-sep">·</span><span>${escapeHtml(lastVisitLbl)}</span>` : ''}
        ${dueLbl ? `<span class="meta-sep">·</span><span style="color:${pct === 100 && status === 'review_needed' ? 'var(--mode-interview)' : 'var(--muted)'}">${escapeHtml(dueLbl)}</span>` : ''}
      </div>
      <div class="card-progress" data-progress-slot="${escapeAttr(c.id)}">
        <div class="progress-bar"><div class="progress-bar-fill" style="width:${pct}%"></div></div>
        <span class="progress-text">${pct}%</span>
        ${qaTotal ? `<span class="qa-progress" data-qa-slot="${escapeAttr(c.id)}">📋 Q&amp;A ${qaAnswered}/${qaTotal}</span>` : ''}
      </div>
    </article>
  `;
}

// Q&A 답변 개수 — qa-aggregator 도입 전 임시 카운터
function countAnswered(c) {
  if (!c.qaNs || !c.qaIds?.length) return 0;
  let n = 0;
  for (const suffix of c.qaIds) {
    const v = localStorage.getItem(c.qaNs + suffix);
    if (v && v.trim().length > 0) n++;
  }
  return n;
}

// ─────────────────────────  Filter UI  ─────────────────────────
function renderFilterBlocks() {
  const counts = {
    area: countBy(state.contents, 'area'),
    coach: countBy(state.contents, 'coach'),
    mode: countBy(state.contents, 'mode'),
    difficulty: countBy(state.contents, 'difficulty'),
  };

  document.getElementById('areaFilters').innerHTML = Object.entries(counts.area)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([area, n]) => filterItemHtml('area', area, AREA_LABEL[area] || area, n, areaDot(area)))
    .join('');

  document.getElementById('coachFilters').innerHTML = Object.entries(counts.coach)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([coach, n]) => filterItemHtml('coach', coach, COACH_LABEL[coach] || coach, n, coachDot(coach)))
    .join('');

  document.getElementById('modeFilters').innerHTML = Object.entries(counts.mode)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([mode, n]) => filterItemHtml('mode', mode, MODE_LABEL[mode] || mode, n))
    .join('');

  const diffEntries = Object.entries(counts.difficulty)
    .filter(([k]) => k !== 'null' && k !== 'undefined')
    .sort(([a], [b]) => +a - +b);
  document.getElementById('difficultyFilters').innerHTML = diffEntries
    .map(([d, n]) => filterItemHtml('difficulty', +d, '●'.repeat(+d) + '○'.repeat(Math.max(0, 5 - +d)), n))
    .join('');

  // 상태 필터 — 진도 데이터 기반 카운트
  const statusCounts = {};
  for (const c of state.contents) {
    const st = progress.get(c.id).status;
    statusCounts[st] = (statusCounts[st] || 0) + 1;
  }
  const STATUS_ORDER = ['not_started', 'in_progress', 'completed', 'review_needed'];
  document.getElementById('statusFilters').innerHTML = STATUS_ORDER
    .filter((st) => statusCounts[st])
    .map((st) => filterItemHtml('status', st, progress._const.STATUS_LABEL[st], statusCounts[st]))
    .join('') || `<p class="muted" style="font-size:11.5px;padding:4px 8px">아직 데이터 없음</p>`;

  document.querySelectorAll('.filter-item input[type="checkbox"]').forEach((cb) => {
    cb.addEventListener('change', onFilterChange);
  });
}

function filterItemHtml(group, value, label, count, dotColor) {
  const id = `f-${group}-${String(value).replace(/[^a-z0-9-]/gi, '_')}`;
  return `
    <label class="filter-item" for="${id}">
      <input type="checkbox" id="${id}" data-group="${group}" data-value="${escapeAttr(String(value))}" />
      ${dotColor ? `<span class="dot" style="background:${dotColor}"></span>` : ''}
      <span>${escapeHtml(label)}</span>
      <span class="count">${count}</span>
    </label>
  `;
}

function areaDot(area) {
  const k = areaToColorKey(area || '');
  return `var(--area-${k}, var(--muted))`;
}
function coachDot(coach) {
  const area = COACH_TO_AREA_TOKEN[coach];
  if (!area) return 'var(--muted)';
  return `var(--area-${areaToColorKey(area)}, var(--muted))`;
}

function onFilterChange(e) {
  const group = e.target.dataset.group;
  const value = e.target.dataset.value;
  const set = state.filters[group];
  if (!set) return;
  // difficulty 는 number
  const v = group === 'difficulty' ? +value : value;
  if (e.target.checked) set.add(v);
  else set.delete(v);
  rerender();
}

function resetFilters() {
  for (const k of Object.keys(state.filters)) state.filters[k].clear();
  state.search = '';
  document.getElementById('searchBox').value = '';
  document.querySelectorAll('.filter-item input[type="checkbox"]').forEach((cb) => (cb.checked = false));
  rerender();
}

// ─────────────────────────  Helpers  ─────────────────────────
function countBy(list, key) {
  const m = {};
  for (const it of list) {
    const v = it[key];
    if (v === null || v === undefined) continue;
    m[v] = (m[v] || 0) + 1;
  }
  return m;
}
function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
function escapeAttr(s) {
  return escapeHtml(s);
}
function debounce(fn, ms) {
  let t;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

// ─────────────────────────  Sidebar Right (영역별 진도)  ─────────────────────────
function renderAreaProgress() {
  const totals = {};
  const dones = {};
  for (const c of state.contents) {
    totals[c.area] = (totals[c.area] || 0) + 1;
    const st = progress.get(c.id).status;
    if (st === progress._const.STATUS.COMPLETED) {
      dones[c.area] = (dones[c.area] || 0) + 1;
    }
  }
  const target = document.getElementById('areaProgress');
  target.innerHTML = Object.entries(totals)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([area, total]) => {
      const lbl = AREA_LABEL[area] || area;
      const dot = areaDot(area);
      const done = dones[area] || 0;
      const pct = total ? Math.round((done / total) * 100) : 0;
      return `
        <div class="area-row" data-area="${escapeAttr(area)}">
          <div class="area-row-head">
            <span class="area-row-name"><span class="dot" style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${dot};vertical-align:middle;margin-right:6px"></span>${escapeHtml(lbl)}</span>
            <span class="area-row-num">${done}/${total} · ${pct}%</span>
          </div>
          <div class="progress-bar"><div class="progress-bar-fill" style="background:${dot};width:${pct}%"></div></div>
        </div>
      `;
    })
    .join('');
}

// 최근 학습 5건
function renderRecent() {
  const target = document.getElementById('recentList');
  const rows = state.contents
    .map((c) => ({ c, rec: progress.get(c.id) }))
    .filter((x) => x.rec.lastVisitedAt)
    .sort((a, b) => Date.parse(b.rec.lastVisitedAt) - Date.parse(a.rec.lastVisitedAt))
    .slice(0, 5);
  if (!rows.length) {
    target.innerHTML = `<p class="muted">아직 학습 기록 없음</p>`;
    return;
  }
  target.innerHTML = rows.map(({ c, rec }) => {
    const dot = areaDot(c.area);
    return `<div style="display:flex;justify-content:space-between;gap:8px;padding:4px 0;font-size:12px;border-bottom:1px dashed var(--border)">
      <a href="./${escapeAttr(c.path)}" target="_blank" rel="noopener" style="color:var(--text);overflow:hidden;text-overflow:ellipsis;white-space:nowrap"><span style="display:inline-block;width:7px;height:7px;border-radius:50%;background:${dot};margin-right:6px;vertical-align:middle"></span>${escapeHtml(c.title || c.path)}</a>
      <span class="muted" style="font-size:11px;white-space:nowrap">${progress.timeAgo(rec.lastVisitedAt)}</span>
    </div>`;
  }).join('');
}

// 오늘 복습 큐
function renderReviewQueue() {
  const target = document.getElementById('reviewQueue');
  const ids = state.contents.map((c) => c.id);
  const due = progress.dueToday(ids);
  if (!due.length) {
    target.innerHTML = `<p class="muted">오늘 복습할 항목 없음</p>`;
    return;
  }
  const idMap = Object.fromEntries(state.contents.map((c) => [c.id, c]));
  target.innerHTML = due.slice(0, 8).map(({ id, rec }) => {
    const c = idMap[id];
    if (!c) return '';
    const dot = areaDot(c.area);
    return `<div style="display:flex;flex-direction:column;gap:4px;padding:6px 0;border-bottom:1px dashed var(--border)">
      <a href="./${escapeAttr(c.path)}" target="_blank" rel="noopener" style="color:var(--text);font-size:12px"><span style="display:inline-block;width:7px;height:7px;border-radius:50%;background:${dot};margin-right:6px;vertical-align:middle"></span>${escapeHtml(c.title || c.path)}</a>
      <div style="display:flex;gap:6px">
        <button class="ghost-btn" style="font-size:10.5px;padding:3px 8px" data-action="review-success" data-id="${escapeAttr(id)}">✓ 성공</button>
        <button class="ghost-btn" style="font-size:10.5px;padding:3px 8px" data-action="review-fail" data-id="${escapeAttr(id)}">✗ 다시</button>
        <button class="ghost-btn" style="font-size:10.5px;padding:3px 8px" data-action="snooze" data-id="${escapeAttr(id)}">💤 내일</button>
      </div>
    </div>`;
  }).join('');
}

// ─────────────────────────  KPIs  ─────────────────────────
function renderKpis() {
  const total = state.contents.length;
  let completed = 0;
  let qaAnswered = 0;
  let qaTotal = 0;
  for (const c of state.contents) {
    const rec = progress.get(c.id);
    if (rec.status === progress._const.STATUS.COMPLETED) completed++;
    qaTotal += c.qaCount || 0;
    qaAnswered += countAnswered(c);
  }
  document.getElementById('kpiProgress').textContent = `${completed}/${total}`;
  const due = progress.dueToday(state.contents.map((c) => c.id));
  document.getElementById('kpiReview').textContent = String(due.length);
  document.getElementById('kpiQa').textContent = String(Math.max(0, qaTotal - qaAnswered));
}

// ─────────────────────────  Wire-up  ─────────────────────────
function rerenderAll() {
  renderCards(applyFilters());
  renderKpis();
  renderAreaProgress();
  renderRecent();
  renderReviewQueue();
}
const rerender = () => renderCards(applyFilters());

function handleCardClick(e) {
  // 1) 카드 본문 링크 클릭 → visit 기록 후 새 탭에서 열림
  const link = e.target.closest('a[data-card-link]');
  if (link) {
    const id = link.dataset.cardLink;
    progress.recordVisit(id);
    // 카드/사이드/KPI 즉시 갱신 (새 탭으로 이동하지만 인덱스 탭은 유지됨)
    setTimeout(rerenderAll, 50);
    return;
  }

  // 2) 카드 액션 버튼
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  const id = btn.dataset.id;
  if (!id) return;
  const action = btn.dataset.action;
  switch (action) {
    case 'toggle-complete': {
      const rec = progress.get(id);
      const isCompleted = rec.status === progress._const.STATUS.COMPLETED || rec.status === progress._const.STATUS.REVIEW_NEEDED;
      if (isCompleted) progress.unmarkCompleted(id);
      else progress.markCompleted(id);
      rerenderAll();
      // 필터 카운트도 갱신 필요
      renderFilterBlocks();
      restoreFilterCheckedState();
      break;
    }
    case 'review-success': progress.reviewSuccess(id); rerenderAll(); renderFilterBlocks(); restoreFilterCheckedState(); break;
    case 'review-fail':    progress.reviewFail(id);    rerenderAll(); renderFilterBlocks(); restoreFilterCheckedState(); break;
    case 'snooze':         progress.snooze(id, 1);     rerenderAll(); break;
  }
}

function restoreFilterCheckedState() {
  document.querySelectorAll('.filter-item input[type="checkbox"]').forEach((cb) => {
    const group = cb.dataset.group;
    const value = group === 'difficulty' ? +cb.dataset.value : cb.dataset.value;
    if (state.filters[group]?.has(value)) cb.checked = true;
  });
}

function bindUi() {
  document.getElementById('searchBox').addEventListener('input', debounce((e) => {
    state.search = e.target.value;
    rerender();
  }, 200));
  document.getElementById('sortSelect').addEventListener('change', (e) => {
    state.sort = e.target.value;
    rerender();
  });
  document.getElementById('resetFilters').addEventListener('click', resetFilters);
  window.addEventListener('jobstudy:reset-filters', resetFilters);

  // 카드 그리드 + 우측 사이드 액션 위임
  document.getElementById('cardGrid').addEventListener('click', handleCardClick);
  document.getElementById('reviewQueue').addEventListener('click', handleCardClick);

  // 다른 탭(HTML 페이지)에서 localStorage가 변경되면 자동 갱신
  window.addEventListener('storage', (e) => {
    if (!e.key) return;
    if (e.key.startsWith(progress._const.NS) || e.key.startsWith('jobStudy::')) {
      rerenderAll();
    }
  });
  // 인덱스 탭이 다시 활성화될 때(다른 탭에서 학습 후 복귀) 갱신
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) rerenderAll();
  });

  // Q&A 통합 뷰 / 백업 모달
  document.getElementById('openQaModal').addEventListener('click', openQaModal);
  document.getElementById('openBackup').addEventListener('click', openBackupModal);
}

// ─────────────────────────  Modals  ─────────────────────────
function openModal(title, contentHtml) {
  closeModal();
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.id = 'modalOverlay';
  overlay.innerHTML = `
    <div class="modal" role="dialog" aria-modal="true">
      <div class="modal-head">
        <h2>${escapeHtml(title)}</h2>
        <button class="modal-close" aria-label="닫기">✕</button>
      </div>
      <div class="modal-body">${contentHtml}</div>
    </div>
  `;
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) closeModal();
  });
  overlay.querySelector('.modal-close').addEventListener('click', closeModal);
  document.body.appendChild(overlay);
  document.body.style.overflow = 'hidden';
  document.addEventListener('keydown', escClose);
}
function closeModal() {
  const o = document.getElementById('modalOverlay');
  if (o) o.remove();
  document.body.style.overflow = '';
  document.removeEventListener('keydown', escClose);
}
function escClose(e) { if (e.key === 'Escape') closeModal(); }

function openQaModal() {
  const groups = qa.aggregate(state.contents);
  const totalAnswered = groups.reduce((s, g) => s + g.answered, 0);
  const totalQ = groups.reduce((s, g) => s + g.total, 0);

  const groupHtml = groups.map((g) => {
    const dot = areaDot(g.area);
    const allAnswered = g.answered === g.total && g.total > 0;
    return `
      <details class="qa-group" ${g.answered > 0 ? 'open' : ''}>
        <summary>
          <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:${dot};margin-right:8px;vertical-align:middle"></span>
          <span class="qa-group-title">${escapeHtml(g.title || g.path)}</span>
          <span class="qa-group-count ${allAnswered ? 'done' : ''}">${g.answered}/${g.total} 답변</span>
        </summary>
        <div class="qa-group-body">
          ${g.ids.map((suffix, i) => {
            const q = g.questions[i] || '(질문 추출 실패)';
            const a = (g.answers[suffix] || '').trim();
            const has = a.length > 0;
            return `
              <div class="qa-item ${has ? 'answered' : 'unanswered'}">
                <div class="qa-q"><strong>Q${i + 1}.</strong> ${escapeHtml(q)}</div>
                ${has ? `<div class="qa-a"><span class="qa-a-label">A.</span> ${escapeHtml(a)}</div>` : `<div class="qa-a empty">✗ 미답변</div>`}
              </div>
            `;
          }).join('')}
          <div class="qa-actions">
            <a class="ghost-btn" href="./${escapeAttr(g.path)}" target="_blank" rel="noopener">📝 페이지 열기</a>
            <button class="ghost-btn" data-qa-action="copy-page" data-id="${escapeAttr(g.id)}">📋 이 페이지 피드백 복사</button>
          </div>
        </div>
      </details>
    `;
  }).join('');

  const html = `
    <div class="qa-toolbar">
      <span class="muted">전체 답변 <strong>${totalAnswered}/${totalQ}</strong></span>
      <div style="margin-left:auto;display:flex;gap:8px">
        <button class="ghost-btn" data-qa-action="copy-all">📋 답변한 전체 복사</button>
        <button class="ghost-btn" data-qa-action="export-json">💾 JSON 다운로드</button>
      </div>
    </div>
    ${groupHtml || `<p class="muted">아직 Q&amp;A가 있는 콘텐츠가 없습니다.</p>`}
    <div id="qaResultMsg" class="qa-result-msg"></div>
  `;

  openModal('📋 Q&A 통합 뷰', html);

  document.querySelector('.modal-body').addEventListener('click', handleQaModalAction);
}

async function handleQaModalAction(e) {
  const btn = e.target.closest('[data-qa-action]');
  if (!btn) return;
  const action = btn.dataset.qaAction;
  const msg = document.getElementById('qaResultMsg');

  if (action === 'copy-page' || action === 'copy-all') {
    const groups = qa.aggregate(state.contents);
    let text;
    if (action === 'copy-page') {
      const g = groups.find((x) => x.id === btn.dataset.id);
      if (!g) return;
      text = qa.formatForFeedback(g);
    } else {
      text = qa.formatAllForFeedback(groups);
      if (!text) { msg.textContent = '⚠️ 답변한 항목이 없습니다.'; return; }
    }
    try {
      await navigator.clipboard.writeText(text);
      msg.textContent = '✓ 클립보드에 복사되었습니다. Claude 채팅창에 붙여넣고 피드백을 요청하세요.';
    } catch (err) {
      msg.textContent = '❌ 복사 실패: ' + err.message;
    }
    return;
  }

  if (action === 'export-json') {
    const snap = qa.exportSnapshot(state.contents);
    const blob = new Blob([JSON.stringify(snap, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    const date = new Date().toISOString().slice(0, 10);
    a.href = url;
    a.download = `jobstudy-qa-export-${date}.json`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
    msg.textContent = `✓ ${Object.keys(snap.answers).length}개 답변이 다운로드되었습니다.`;
  }
}

function openBackupModal() {
  const snap = qa.exportSnapshot(state.contents);
  const progressAll = progress.getAll();
  const date = new Date().toISOString().slice(0, 10);
  const html = `
    <p class="muted" style="margin-bottom:14px">학습 진도와 Q&A 답변을 JSON으로 백업/복원합니다. Git에 커밋해 두면 다른 기기에서도 복원할 수 있습니다.</p>

    <h3 style="margin:18px 0 8px;font-size:13px">현재 상태</h3>
    <ul style="margin:0 0 14px;font-size:13px">
      <li>Q&amp;A 답변: <strong>${Object.keys(snap.answers).length}</strong>개</li>
      <li>진도 기록: <strong>${Object.keys(progressAll).length}</strong>개</li>
    </ul>

    <h3 style="margin:18px 0 8px;font-size:13px">📤 내보내기</h3>
    <div style="display:flex;gap:8px;margin-bottom:14px;flex-wrap:wrap">
      <button class="ghost-btn" id="backupExportQa">💾 Q&amp;A JSON 다운로드</button>
      <button class="ghost-btn" id="backupExportProgress">💾 진도 JSON 다운로드</button>
      <button class="primary-btn" id="backupExportAll">💾 전체 (Q&amp;A + 진도)</button>
    </div>
    <p class="muted" style="font-size:12px">다운로드 후 터미널에서:<br />
      <code style="background:#f1f5f9;padding:2px 6px;border-radius:4px;font-size:11.5px">node scripts/export-qa.mjs ~/Downloads/jobstudy-qa-export-${date}.json</code>
    </p>

    <h3 style="margin:22px 0 8px;font-size:13px">📥 복원</h3>
    <p class="muted" style="font-size:12px;margin-bottom:8px">JSON 파일을 선택하세요. 동일 키는 덮어씁니다.</p>
    <input type="file" id="backupImportFile" accept="application/json" />
    <label style="margin:8px 0;display:flex;align-items:center;gap:8px;font-size:12.5px">
      <input type="checkbox" id="backupOverwrite" checked /> 기존 답변 덮어쓰기
    </label>

    <div id="backupResultMsg" class="qa-result-msg"></div>
  `;
  openModal('💾 JSON 백업/복원', html);
  bindBackupModal();
}

function bindBackupModal() {
  const date = new Date().toISOString().slice(0, 10);
  const msg = () => document.getElementById('backupResultMsg');
  const dl = (obj, name) => {
    const blob = new Blob([JSON.stringify(obj, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove();
    URL.revokeObjectURL(url);
  };

  document.getElementById('backupExportQa').addEventListener('click', () => {
    dl(qa.exportSnapshot(state.contents), `jobstudy-qa-export-${date}.json`);
    msg().textContent = '✓ Q&A 다운로드 완료';
  });
  document.getElementById('backupExportProgress').addEventListener('click', () => {
    dl({ version: 1, exportedAt: new Date().toISOString(), progress: progress.getAll() }, `jobstudy-progress-export-${date}.json`);
    msg().textContent = '✓ 진도 다운로드 완료';
  });
  document.getElementById('backupExportAll').addEventListener('click', () => {
    dl({
      version: 1,
      exportedAt: new Date().toISOString(),
      answers: qa.exportSnapshot(state.contents).answers,
      progress: progress.getAll(),
    }, `jobstudy-full-export-${date}.json`);
    msg().textContent = '✓ 전체 다운로드 완료';
  });

  document.getElementById('backupImportFile').addEventListener('change', async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const text = await file.text();
      const json = JSON.parse(text);
      const overwrite = document.getElementById('backupOverwrite').checked;
      let report = [];
      if (json.answers) {
        const r = qa.importSnapshot(json, { overwrite });
        report.push(`Q&A: ${r.written}건 복원, ${r.skipped}건 건너뜀`);
      }
      if (json.progress) {
        let n = 0;
        for (const [id, rec] of Object.entries(json.progress)) {
          if (!overwrite && localStorage.getItem(progress._const.NS + id)) continue;
          progress.set(id, rec);
          n++;
        }
        report.push(`진도: ${n}건 복원`);
      }
      msg().textContent = '✓ ' + report.join(' · ');
      rerenderAll();
      renderFilterBlocks();
      restoreFilterCheckedState();
    } catch (err) {
      msg().textContent = '❌ 복원 실패: ' + err.message;
    }
  });
}

// ─────────────────────────  Theme  ─────────────────────────
const THEME_KEY = 'jobStudy::ui::theme';

function applyTheme(t) {
  document.documentElement.setAttribute('data-theme', t);
  const btn = document.getElementById('themeToggle');
  if (btn) btn.textContent = t === 'dark' ? '☀️' : '🌙';
}
function initTheme() {
  const saved = localStorage.getItem(THEME_KEY);
  if (saved) {
    applyTheme(saved);
  } else {
    const prefersDark = window.matchMedia?.('(prefers-color-scheme: dark)').matches;
    applyTheme(prefersDark ? 'dark' : 'light');
  }
  document.getElementById('themeToggle')?.addEventListener('click', () => {
    const cur = document.documentElement.getAttribute('data-theme') || 'light';
    const next = cur === 'dark' ? 'light' : 'dark';
    localStorage.setItem(THEME_KEY, next);
    applyTheme(next);
  });
}

(async function init() {
  initTheme();
  await loadContents();
  renderFilterBlocks();
  bindUi();
  rerenderAll();
})();

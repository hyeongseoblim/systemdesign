// jobStudy 학습 페이지 위젯
// 학습 HTML 에 한 줄로 추가:
//   <script type="module" src="<상대경로>/assets/study-widget.js"></script>
// 페이지 안에 `window.NS = 'jobStudy::<path>::<file>::'` 가 정의되어 있다는 가정.
// (모든 학습 HTML 의 Q&A 입력 영역이 이미 NS 를 정의함)

import * as progress from './progress.js';

(function init() {
  const NS = window.NS;
  if (typeof NS !== 'string' || !NS.startsWith('jobStudy::')) {
    console.warn('[study-widget] window.NS 미정의 — 위젯 비활성');
    return;
  }
  const id = NS.replace(/^jobStudy::/, '').replace(/::$/, '').replace(/::/g, '/');

  // 페이지 깊이 → 인덱스 백 링크 ("backend/architecture/00-introduction" → "../../index.html")
  const depth = id.split('/').length - 1; // "system-design/00" -> 1
  const indexHref = '../'.repeat(depth) + 'index.html';

  // visit 기록 + 진행 중으로 마킹
  progress.recordVisit(id);

  // ── UI ──────────────────────────────────────────────
  const root = document.createElement('div');
  root.id = 'jobstudy-study-widget';
  root.innerHTML = `
    <a class="sw-back" href="${indexHref}" title="대시보드로 돌아가기">← 인덱스</a>
    <span class="sw-sep">·</span>
    <span class="sw-status"></span>
    <span class="sw-sep">·</span>
    <span class="sw-dwell" title="누적 활성 학습 시간"></span>
    <span class="sw-sep">·</span>
    <span class="sw-visit" title="방문 횟수"></span>
    <button class="sw-toggle" type="button"></button>
  `;
  const style = document.createElement('style');
  style.textContent = `
    #jobstudy-study-widget {
      position: fixed; top: 14px; left: 264px; z-index: 9998;
      display: inline-flex; align-items: center; gap: 8px;
      padding: 7px 13px; border-radius: 999px;
      background: #ffffff; border: 1px solid #e2e8f0;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      font-family: -apple-system, BlinkMacSystemFont, "Noto Sans KR", sans-serif;
      font-size: 12px; color: #475569;
    }
    #jobstudy-study-widget .sw-back { color: #4f46e5; text-decoration: none; font-weight: 500; }
    #jobstudy-study-widget .sw-back:hover { text-decoration: underline; }
    #jobstudy-study-widget .sw-sep { color: #cbd5e1; }
    #jobstudy-study-widget .sw-status { font-weight: 500; }
    #jobstudy-study-widget .sw-status.completed,
    #jobstudy-study-widget .sw-status.review_needed { color: #16a34a; }
    #jobstudy-study-widget .sw-status.in_progress { color: #ea580c; }
    #jobstudy-study-widget .sw-toggle {
      margin-left: 6px; padding: 4px 10px; border-radius: 999px;
      border: 1px solid #e2e8f0; background: #f8fafc; cursor: pointer;
      font: inherit; color: inherit;
    }
    #jobstudy-study-widget .sw-toggle:hover { background: #f1f5f9; }
    #jobstudy-study-widget .sw-toggle.is-completed {
      background: #dcfce7; border-color: #86efac; color: #15803d;
    }
    @media (max-width: 900px) {
      #jobstudy-study-widget { left: 14px; right: auto; top: auto; bottom: 14px; }
    }
  `;
  document.head.appendChild(style);
  document.body.appendChild(root);

  const STATUS_LBL = progress._const.STATUS_LABEL;

  function render() {
    const rec = progress.get(id);
    const isCompleted =
      rec.status === progress._const.STATUS.COMPLETED ||
      rec.status === progress._const.STATUS.REVIEW_NEEDED;
    const statusEl = root.querySelector('.sw-status');
    statusEl.className = 'sw-status ' + rec.status;
    statusEl.textContent = STATUS_LBL[rec.status] || rec.status;
    root.querySelector('.sw-dwell').textContent = '⏱ ' + progress.formatDwell(rec.dwellMs || 0);
    root.querySelector('.sw-visit').textContent = '📊 ' + (rec.visitCount || 0) + '회';
    const toggle = root.querySelector('.sw-toggle');
    toggle.classList.toggle('is-completed', isCompleted);
    toggle.textContent = isCompleted ? '✓ 완료됨' : '○ 완료 표시';
    toggle.title = isCompleted ? '완료 해제' : '학습 완료로 표시 (SRS 큐에 등록됨)';
  }

  root.querySelector('.sw-toggle').addEventListener('click', () => {
    const rec = progress.get(id);
    const isCompleted =
      rec.status === progress._const.STATUS.COMPLETED ||
      rec.status === progress._const.STATUS.REVIEW_NEEDED;
    if (isCompleted) progress.unmarkCompleted(id);
    else progress.markCompleted(id);
    render();
  });

  render();

  // ── Dwell time 누적 ──────────────────────────────────
  // 페이지가 보이는 동안만 측정. visibilitychange/beforeunload/주기 flush.
  let activeStart = document.hidden ? null : Date.now();

  function flush() {
    if (activeStart == null) return;
    const ms = Date.now() - activeStart;
    activeStart = Date.now();
    progress.addDwell(id, ms);
    render();
  }

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      flush();
      activeStart = null;
    } else if (activeStart == null) {
      activeStart = Date.now();
    }
  });
  // 탭 닫힘 / 새로고침
  window.addEventListener('beforeunload', flush);
  window.addEventListener('pagehide', flush);
  // 30초마다 주기 flush — beforeunload 가 모바일에서 안정적이지 않음
  setInterval(flush, 30 * 1000);
})();

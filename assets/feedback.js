// jobStudy — 코치 피드백 textarea 자동 와이어링
//
// 각 학습 HTML 페이지의 .fb-area 안에 있는 textarea[id^="fb"] 를 자동으로:
//   1) 페이지 로드 시 localStorage 에서 값 복원
//   2) 입력 시 NS+id 키로 자동 저장 (디바운스 400ms)
//   3) "미리보기" 토글 버튼으로 marked.js 마크다운 렌더 ↔ 편집 전환
//
// 의존: window.NS (각 HTML 페이지가 정의), marked (CDN 으로 동적 로드)
// qna-sync.js 가 textarea[id^="fb"] 도 함께 cloud 로 push/pull 한다.
(function () {
  if (typeof window === 'undefined') return;

  const NS = window.NS;
  if (!NS) {
    console.warn('[feedback] NS 가 정의되지 않음 — 와이어링 건너뜀');
    return;
  }

  // marked CDN — 페이지에 이미 로드돼 있지 않으면 1회 동적 로드
  const MARKED_URL = 'https://cdn.jsdelivr.net/npm/marked@11/marked.min.js';
  let markedReady = null;
  function ensureMarked() {
    if (typeof window.marked !== 'undefined') return Promise.resolve(window.marked);
    if (markedReady) return markedReady;
    markedReady = new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = MARKED_URL;
      s.async = true;
      s.onload = () => resolve(window.marked);
      s.onerror = () => reject(new Error('marked 로드 실패'));
      document.head.appendChild(s);
    });
    return markedReady;
  }

  // 사용자가 직접 코치 답변을 붙여넣는 학습용 페이지지만, 최소한의 XSS 차단.
  function safeRender(text) {
    if (!window.marked) return escapeHtml(text);
    let html;
    try {
      html = window.marked.parse(text, { gfm: true, breaks: true });
    } catch (e) {
      console.warn('[feedback] marked.parse 실패', e);
      return escapeHtml(text);
    }
    return html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, '')
      .replace(/\son[a-z]+\s*=\s*"[^"]*"/gi, '')
      .replace(/\son[a-z]+\s*=\s*'[^']*'/gi, '')
      .replace(/javascript:/gi, '');
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // textarea id → 미리보기 div id, 저장 배지 id, 토글 버튼 (data-fb-target)
  function findPreviewFor(textarea) {
    const id = textarea.id;
    // 우선순위: data-fb-preview 속성 → "preview-<id>" → 가장 가까운 .fb-area 안의 .fb-preview
    const attr = textarea.dataset.fbPreview;
    if (attr) {
      const el = document.getElementById(attr);
      if (el) return el;
    }
    const guess = document.getElementById('preview-' + id);
    if (guess) return guess;
    const area = textarea.closest('.fb-area');
    if (area) return area.querySelector('.fb-preview');
    return null;
  }

  function findToggleFor(textarea) {
    const area = textarea.closest('.fb-area');
    if (!area) return null;
    return area.querySelector(`.fb-toggle[data-fb-target="${textarea.id}"]`) ||
      area.querySelector('.fb-toggle');
  }

  function findBadgeFor(textarea) {
    const area = textarea.closest('.fb-area');
    if (!area) return null;
    return area.querySelector('.fb-saved-badge');
  }

  function wireOne(el) {
    const key = NS + el.id;
    const saved = localStorage.getItem(key);
    if (saved && !el.value) el.value = saved;

    const badge = findBadgeFor(el);
    let t;
    el.addEventListener('input', () => {
      clearTimeout(t);
      t = setTimeout(() => {
        localStorage.setItem(key, el.value);
        if (badge) {
          badge.classList.add('show');
          setTimeout(() => badge.classList.remove('show'), 1800);
        }
      }, 400);
    });

    // 미리보기 토글
    const toggle = findToggleFor(el);
    const preview = findPreviewFor(el);
    if (toggle && preview) {
      toggle.addEventListener('click', async () => {
        const isPreview = !preview.hasAttribute('hidden');
        if (isPreview) {
          // 미리보기 → 편집
          preview.hidden = true;
          el.hidden = false;
          toggle.classList.remove('active');
          toggle.textContent = '미리보기';
        } else {
          // 편집 → 미리보기
          try {
            await ensureMarked();
          } catch (e) {
            console.warn('[feedback] marked 로드 실패, 평문으로 표시', e);
          }
          preview.innerHTML = safeRender(el.value || '_(피드백 없음)_');
          preview.hidden = false;
          el.hidden = true;
          toggle.classList.add('active');
          toggle.textContent = '편집';
        }
      });
    }
  }

  function init() {
    document.querySelectorAll('textarea[id^="fb"]').forEach(wireOne);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

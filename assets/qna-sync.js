// jobStudy Q&A — cloud sync via Cloudflare Worker
// Wraps existing inline saveAns/localStorage logic. Keep this file framework-agnostic.
(function () {
  const WORKER = 'https://systemdesign.idlagudtjqi.workers.dev';
  const KEY_STORE = 'jobStudy::syncKey';

  // ── 1) study key (prompt once, cache in localStorage) ──
  let studyKey = localStorage.getItem(KEY_STORE);
  if (!studyKey) {
    const k = prompt('동기화 키를 입력하세요\n(Cloudflare Worker의 STUDY_KEY 값)');
    if (!k || !k.trim()) {
      console.warn('[qna-sync] no key supplied; sync disabled');
      return;
    }
    studyKey = k.trim();
    localStorage.setItem(KEY_STORE, studyKey);
  }

  // ── 2) page path from NS (e.g. jobStudy::cs::00-introduction:: -> cs/00-introduction) ──
  if (typeof NS === 'undefined' || !NS) {
    console.warn('[qna-sync] NS not defined on this page; sync disabled');
    return;
  }
  const pagePath = NS.replace(/^jobStudy::/, '').replace(/::$/, '').replace(/::/g, '/');

  // ── 3) status indicator (top-right pill, click to reset key) ──
  const indicator = document.createElement('div');
  Object.assign(indicator.style, {
    position: 'fixed', top: '14px', right: '14px', zIndex: '9999',
    padding: '6px 12px', borderRadius: '999px',
    background: '#ffffff', border: '1px solid #e2e8f0',
    fontSize: '12px', fontFamily: "-apple-system,BlinkMacSystemFont,'Noto Sans KR',sans-serif",
    color: '#64748b', boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
    cursor: 'pointer', userSelect: 'none',
  });
  indicator.title = '클릭하여 동기화 키 재설정';
  indicator.textContent = '⟳ 준비 중';
  indicator.onclick = () => {
    if (confirm('동기화 키를 다시 입력하시겠어요?')) {
      localStorage.removeItem(KEY_STORE);
      location.reload();
    }
  };
  function setStatus(text, color) {
    indicator.textContent = text;
    indicator.style.color = color || '#64748b';
  }
  function attachIndicator() {
    if (document.body && !document.body.contains(indicator)) {
      document.body.appendChild(indicator);
    }
  }

  // ── 4) collect / push / pull ──
  function collectAnswers() {
    const out = {};
    document.querySelectorAll('textarea[id^="ans"]').forEach((el) => {
      if (el.value && el.value.trim()) out[el.id] = el.value;
    });
    return out;
  }

  let pushTimer = null;
  function schedulePush() {
    setStatus('● 입력 중', '#ea580c');
    clearTimeout(pushTimer);
    pushTimer = setTimeout(pushToCloud, 1500);
  }

  async function pushToCloud() {
    const answers = collectAnswers();
    setStatus('⟳ 동기화 중', '#0284c7');
    try {
      const r = await fetch(WORKER + '/save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Study-Key': studyKey },
        body: JSON.stringify({ path: pagePath, answers }),
      });
      if (r.status === 401) { setStatus('⚠ 키 오류 (클릭 재설정)', '#dc2626'); return; }
      if (!r.ok) throw new Error('HTTP ' + r.status);
      setStatus('✓ 동기화됨', '#16a34a');
    } catch (e) {
      console.warn('[qna-sync] push failed', e);
      setStatus('⚠ 오프라인', '#dc2626');
    }
  }

  async function pullFromCloud() {
    setStatus('⟳ 불러오는 중', '#0284c7');
    try {
      const r = await fetch(WORKER + '/load?path=' + encodeURIComponent(pagePath), {
        headers: { 'X-Study-Key': studyKey },
      });
      if (r.status === 401) { setStatus('⚠ 키 오류 (클릭 재설정)', '#dc2626'); return; }
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const data = await r.json();
      const cloud = data.answers || {};
      let restored = 0;
      Object.entries(cloud).forEach(([id, val]) => {
        const el = document.getElementById(id);
        if (el && el.tagName === 'TEXTAREA' && !el.value.trim() && val) {
          el.value = val;
          // Trigger existing inline handlers so localStorage stays in sync
          el.dispatchEvent(new Event('input', { bubbles: true }));
          restored++;
        }
      });
      setStatus(restored > 0 ? '✓ ' + restored + '개 복원' : '✓ 동기화됨', '#16a34a');
    } catch (e) {
      console.warn('[qna-sync] pull failed', e);
      setStatus('⚠ 오프라인', '#dc2626');
    }
  }

  function attachListeners() {
    document.querySelectorAll('textarea[id^="ans"]').forEach((el) => {
      el.addEventListener('input', schedulePush);
    });
  }

  function init() {
    attachIndicator();
    // Pull first, then attach push listeners (avoid pull triggering push loop).
    pullFromCloud().finally(attachListeners);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

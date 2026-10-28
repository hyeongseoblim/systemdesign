import { chromium } from '../apps/web/node_modules/playwright/index.mjs';
import { expect as baseExpect } from '../apps/web/node_modules/@playwright/test/index.mjs';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
const base = process.env.WEB_BASE || 'http://localhost:3000';
const api = process.env.API_BASE || base + '/api/study';
const cardsPath = process.env.API_BASE ? '/api/v1/cards' : '/cards';
const output = process.env.UX_ARTIFACTS || '/tmp/jobstudy-study-ux';
await mkdir(output, { recursive: true });
const expect = baseExpect.configure({ timeout: 15000 });
const apiJson = url => JSON.parse(execFileSync('curl', ['-fsS', '--retry', '2', '--max-time', '30', url], { encoding: 'utf8', timeout: 100000 }));
let cards = [], cursor;
do {
  const feed = apiJson(`${api}${cardsPath}?limit=100${cursor ? '&cursor=' + encodeURIComponent(cursor) : ''}`);
  cards.push(...feed.items); cursor = feed.nextCursor;
} while (cursor);
const starter = cards.find(c => c.slug === 'backend-01-api-design');
const nextStarter = cards.find(c => c.slug === 'database-01-index-explain');
const regular = cards.find(c => c.slug === 'backend-03-transaction');
const details = apiJson(`${api}${cardsPath}/${regular.id}`);
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : undefined), headless: true });
const results = [];
async function page(width = 390) { const context = await browser.newContext({ viewport: { width, height: 844 } }); return { context, page: await context.newPage() }; }
async function home(p) { await p.goto(base); await expect(p.locator('.home-focus')).toHaveAttribute('aria-busy', 'false'); }
async function at(p, card) { await p.goto(`${base}/cards/${card.id}`); await expect(p.locator('.recall-input textarea').first()).toBeVisible(); }
try {
  // Starting point is visible in the first mobile screen, with an accessible tap target.
  for (const width of [320, 390, 768, 1280]) {
    const { context, page: p } = await page(width); await home(p);
    const geometry = await p.locator('.home-focus-cta').evaluate(el => ({ top: el.getBoundingClientRect().top, bottom: el.getBoundingClientRect().bottom, height: el.clientHeight, pageWidth: document.documentElement.scrollWidth, width: document.documentElement.clientWidth }));
    assert.ok(geometry.bottom < 770, `CTA below first screen at ${width}: ${JSON.stringify(geometry)}`);
    assert.ok(geometry.height >= 44); assert.ok(geometry.pageWidth <= geometry.width + 1);
    await expect(p.locator('.home-focus-cta')).toHaveAttribute('href', new RegExp(starter.id));
    if (width === 390) await p.screenshot({ path: `${output}/home-after.png` });
    results.push({ flow: 'home-primary', width, ...geometry }); await context.close();
  }
  {
    const { context, page: p } = await page();
    await p.route('**/api/study/cards?**', route => route.abort('failed'));
    await p.goto(base); await expect(p.locator('.catalog-status[role="alert"]')).toBeVisible();
    await expect(p.locator('.home-focus')).toHaveAttribute('aria-busy', 'false');
    await p.unroute('**/api/study/cards?**'); await p.getByRole('button', { name: '다시 시도', exact: true }).click();
    await expect(p.locator('.home-focus-cta')).toHaveAttribute('href', new RegExp(starter.id));
    results.push({ flow: 'catalog-failure-and-retry', passed: true }); await context.close();
  }
  {
    const { context, page: p } = await page(); await home(p); await p.locator('.home-focus-cta').click();
    const input = p.getByRole('textbox', { name: '떠올린 답변', exact: true });
    await input.fill('주문 한 건은 GET /orders/{id}로 조회한다.');
    await p.reload(); await expect(input).toHaveValue('주문 한 건은 GET /orders/{id}로 조회한다.');
    await p.getByText('예시 답과 비교하기', { exact: true }).click(); await expect(p.locator('.quick-answer')).toBeVisible();
    await p.getByRole('button', { name: '복습에 저장', exact: true }).click();
    assert.equal(await p.evaluate(id => localStorage.getItem(`jobStudy::mastery::${id}`), starter.id), 'review');
    await p.getByRole('button', { name: '✓ 복습에 저장됨 · 해제', exact: true }).click();
    assert.equal(await p.evaluate(id => localStorage.getItem(`jobStudy::mastery::${id}`), starter.id), null);
    await p.getByRole('button', { name: '학습 완료로 표시', exact: true }).click();
    assert.ok(await p.evaluate(id => localStorage.getItem(`jobStudy::done::${id}`), starter.id));
    await p.locator('.completion-next').getByRole('link', { name: '다음 학습 고르기 →', exact: true }).click();
    await expect(p.locator('.home-focus')).toHaveAttribute('aria-busy', 'false');
    await expect(p.locator('.home-focus-cta')).toHaveAttribute('href', new RegExp(nextStarter.id));
    results.push({ flow: 'starter-recall-save-complete-next', passed: true }); await context.close();
  }
  {
    const { context, page: p } = await page(); await p.goto(base + '/manifest.webmanifest');
    await p.evaluate(({ card, question }) => localStorage.setItem(`jobStudy::ans::${card}::${question}`, '이전에 저장한 답변'), { card: regular.id, question: details.questions[0].id });
    await at(p, regular); await expect(p.getByRole('textbox', { name: 'Q2 답변', exact: true })).toBeVisible();
    await p.getByRole('button', { name: /질문 1/ }).click(); const input = p.getByRole('textbox', { name: 'Q1 답변', exact: true });
    await expect(input).toHaveValue('이전에 저장한 답변'); await input.fill('MVCC의 문장별 스냅샷과 트랜잭션 경계를 구분한다.');
    await p.getByText('내 답과 점검 기준 비교하기', { exact: true }).click(); const checkbox = p.locator('.guide-checklist input').first(); await checkbox.check();
    await p.getByRole('button', { name: '다음 질문 →', exact: true }).click(); await p.getByRole('textbox', { name: 'Q2 답변', exact: true }).fill('DB 커밋과 외부 호출은 원자적으로 묶이지 않아 Outbox가 필요하다.');
    await p.reload(); await expect(p.getByRole('textbox', { name: 'Q2 답변', exact: true })).toHaveValue('DB 커밋과 외부 호출은 원자적으로 묶이지 않아 Outbox가 필요하다.');
    await p.getByRole('button', { name: /질문 1/ }).click(); await expect(input).toHaveValue('MVCC의 문장별 스냅샷과 트랜잭션 경계를 구분한다.');
    await p.getByText('내 답과 점검 기준 비교하기', { exact: true }).click(); await expect(checkbox).toBeChecked();
    await p.getByRole('button', { name: /질문 3/ }).click(); await expect(p.locator('.qtext code').first()).toBeVisible();
    assert.ok(!(await p.locator('.qtext').innerText()).includes('`'));
    await p.locator('.recall-navigation').getByRole('link').click();
    await p.getByRole('button', { name: '힌트가 있으면 설명 가능', exact: true }).click(); await p.getByRole('button', { name: '학습 완료로 표시', exact: true }).click();
    await p.locator('.completion-next').getByRole('link', { name: '내 복습 목록', exact: true }).click();
    const review = p.locator('.feed a.card').filter({ has: p.getByRole('heading', { name: regular.title, exact: true }) });
    await expect(review).toBeVisible(); await review.click(); await expect(p.locator('a.back')).toHaveAttribute('href', /view=review/);
    await p.locator('#questions').scrollIntoViewIfNeeded(); await expect(p.locator('.dock-primary')).toContainText('이해도 기록'); await p.screenshot({ path: `${output}/recall-after.png` });
    results.push({ flow: 'legacy-answer-checklist-question-resume-review-return', passed: true }); await context.close();
  }
  {
    const { context, page: p } = await page(); await at(p, regular);
    const y = await p.locator('.diagram-image').first().evaluate(el => {
      const y = el.getBoundingClientRect().top + scrollY + Math.min(650, el.clientHeight / 2);
      scrollTo({ top: y, behavior: 'instant' }); return y;
    });
    await expect.poll(() => p.evaluate(id => JSON.parse(localStorage.getItem(`jobStudy::position-offset::${id}`) || 'null')?.offset || 0, regular.id)).toBeGreaterThan(500);
    await home(p); await expect(p.locator('.home-focus-cta')).toHaveAttribute('href', /#resume$/); await p.locator('.home-focus-cta').click();
    await expect.poll(() => p.evaluate(() => Math.round(scrollY))).toBeGreaterThan(y - 80);
    assert.ok(Math.abs((await p.evaluate(() => scrollY)) - y) < 80);
    results.push({ flow: 'long-diagram-position-direct-home-resume', y, restored: await p.evaluate(() => scrollY) }); await context.close();
  }
  {
    const { context, page: p } = await page(); await at(p, starter);
    await p.locator('.starter-deep-dive > summary').click();
    const target = await p.locator('.content h2[id]').first().getAttribute('id');
    await p.evaluate(id => scrollTo({ top: document.getElementById(id).getBoundingClientRect().top + scrollY + 260, behavior: 'instant' }), target);
    await expect.poll(() => p.evaluate(id => localStorage.getItem(`jobStudy::position::${id}`), starter.id)).toBe(target);
    await home(p); await p.locator('.home-focus-cta').click();
    await expect(p.locator('.starter-deep-dive')).toHaveAttribute('open', '');
    await expect.poll(() => p.evaluate(() => scrollY)).toBeGreaterThan(1000);
    results.push({ flow: 'resume-opens-collapsed-deep-reading', passed: true }); await context.close();
  }
  {
    const { context, page: p } = await page(); await at(p, regular);
    const target = await p.locator('.content h2[id]').first().getAttribute('id');
    await p.evaluate(({ id, target }) => { localStorage.setItem(`jobStudy::position::${id}`, target); localStorage.removeItem(`jobStudy::position-offset::${id}`); }, { id: regular.id, target });
    await p.reload(); await p.getByRole('button', { name: '이어서 읽기 ↓', exact: true }).click();
    await expect.poll(() => p.evaluate(id => Math.abs(document.getElementById(id).getBoundingClientRect().top - 96), target)).toBeLessThan(20);
    results.push({ flow: 'legacy-heading-position-resume', passed: true }); await context.close();
  }
  {
    const { context, page: p } = await page();
    const response = await p.request.get(base + '/api/study/cards?area=DATABASE&limit=2&upstream=https://example.invalid');
    assert.equal(response.status(), 200); const feed = await response.json(); assert.equal(feed.items.length, 2); assert.ok(feed.items.every(c => c.area === 'DATABASE'));
    assert.equal((await p.request.get(base + '/api/study/cards/not-a-uuid')).status(), 400);
    assert.equal((await p.request.post(base + '/api/study/cards')).status(), 405);
    results.push({ flow: 'same-origin-public-read-only-card-proxy', passed: true }); await context.close();
  }
  {
    const { context, page: p } = await page();
    await context.addInitScript(() => { Storage.prototype.setItem = function () { throw new DOMException('blocked', 'QuotaExceededError'); }; });
    await at(p, starter); const input = p.getByRole('textbox', { name: '떠올린 답변', exact: true }); await input.fill('저장 실패 시에도 화면의 답변은 유지한다.');
    await expect(p.locator('.quick-question .recall-save')).toContainText('저장하지 못했어요'); await expect(input).toHaveValue('저장 실패 시에도 화면의 답변은 유지한다.');
    results.push({ flow: 'storage-failure-keeps-draft-with-error', passed: true }); await context.close();
  }
  {
    const { context, page: p } = await page(320); await at(p, regular); await p.emulateMedia({ colorScheme: 'dark' }); await p.reload();
    await p.locator('#questions').scrollIntoViewIfNeeded(); await expect(p.locator('.recall-input textarea')).toBeVisible();
    const font = await p.locator('.recall-input textarea').evaluate(el => getComputedStyle(el).fontSize); assert.equal(font, '16px');
    assert.ok(await p.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1));
    await p.screenshot({ path: `${output}/recall-dark-320.png` }); results.push({ flow: 'dark-small-mobile-recall', passed: true }); await context.close();
  }
  await writeFile(`${output}/results.json`, JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
} finally { await browser.close(); }

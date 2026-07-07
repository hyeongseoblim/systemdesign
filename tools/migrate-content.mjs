// 기존 학습 HTML → 카드 JSON 변환기
// 사용: node tools/migrate-content.mjs   → tools/migrated-cards.json 생성
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import * as cheerio from "cheerio";
import TurndownService from "turndown";
import { gfm } from "turndown-plugin-gfm";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// 파일 → 카드 메타 매핑 (area/mode/coach/difficulty/tags)
const SOURCES = [
  { file: "cs/00-introduction.html", area: "CS", mode: "CONCEPT", coach: "cs-fundamentals-coach", difficulty: 3, tags: ["cs", "os", "network", "concurrency"] },
  { file: "database/00-introduction.html", area: "DATABASE", mode: "CONCEPT", coach: "database-coach", difficulty: 3, tags: ["rdbms", "index", "transaction", "sharding"] },
  { file: "infra/00-introduction.html", area: "INFRA", mode: "CONCEPT", coach: "infra-coach", difficulty: 3, tags: ["aws", "kubernetes", "cicd", "sre"] },
  { file: "logistics/00-domain-overview.html", area: "LOGISTICS", mode: "CONCEPT", coach: "logistics-domain-coach", difficulty: 3, tags: ["oms", "wms", "tms", "last-mile"] },
  { file: "backend/00-introduction.html", area: "BACKEND_DEV", mode: "CONCEPT", coach: "backend-dev-coach", difficulty: 3, tags: ["spring", "transaction", "testing", "observability"] },
  { file: "backend/architecture/00-introduction.html", area: "BACKEND_ARCHITECTURE", mode: "CONCEPT", coach: "backend-architecture-coach", difficulty: 3, tags: ["msa", "ddd", "saga", "outbox", "cqrs"] },
  { file: "system-design/00-introduction.html", area: "SYSTEM_DESIGN", mode: "CONCEPT", coach: "system-design-coach", difficulty: 3, tags: ["system-design", "estimation", "cap", "trade-off"] },
  { file: "system-design/01-url-shortener.html", area: "SYSTEM_DESIGN", mode: "DESIGN", coach: "system-design-coach", difficulty: 3, tags: ["url-shortener", "cache", "base62", "keyset"] },
];

const td = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
  bulletListMarker: "-",
});
td.use(gfm);
// mermaid placeholder(pre[data-mermaid]) → 펜스 코드블록
td.addRule("mermaid", {
  filter: (node) => node.nodeName === "PRE" && node.getAttribute("data-mermaid") === "1",
  replacement: (_c, node) => `\n\`\`\`mermaid\n${node.textContent.trim()}\n\`\`\`\n`,
});

function convert({ file, ...meta }) {
  const html = readFileSync(resolve(ROOT, file), "utf8");
  const $ = cheerio.load(html);

  const title = $("title").text().trim();
  const summary = $(".page-hdr p").first().text().trim().replace(/\s+/g, " ") || null;

  // 질문 추출 (.q-card 안의 첫 <p>)
  const questions = [];
  $(".q-card").each((_, el) => {
    const q = $(el).find("p").first().text().trim().replace(/\s+/g, " ");
    if (q) questions.push(q);
  });

  // 본문 정리: 비콘텐츠 요소 제거
  $("#sidebar, nav, script, style, link, .feedback-box, .ans-area, .wip-banner").remove();
  $("section#qa, section#quiz, section#next").remove(); // Q&A/다음학습 섹션은 카드 questions로 대체
  $(".chips").remove();
  $(".page-hdr h1").remove(); // 제목은 카드 title 필드로

  // mermaid 다이어그램 → 원문 보존용 placeholder
  $(".mermaid").each((_, el) => {
    const code = $(el).text().trim();
    $(el).replaceWith(`<pre data-mermaid="1">${escapeHtml(code)}</pre>`);
  });
  // 다이어그램 캡션은 이탤릭으로
  $(".diagram-wrap .cap").each((_, el) => $(el).replaceWith(`<p><em>${$(el).text().trim()}</em></p>`));
  // callout → 인용구 + 굵은 제목
  $(".callout").each((_, el) => {
    const t = $(el).find(".c-title").text().trim();
    $(el).find(".c-title").remove();
    $(el).replaceWith(`<blockquote><p><strong>${t}</strong></p>${$(el).html()}</blockquote>`);
  });

  const bodyHtml = $("main").html() ?? $("body").html() ?? "";
  const contentMd = td
    .turndown(bodyHtml)
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  const slug = file.replace(/\.html$/, "").replace(/[\/]/g, "-");
  return { ...meta, title, slug, summary, contentMd, questions, publishNow: true };
}

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

const cards = SOURCES.map(convert);
const out = resolve(ROOT, "tools/migrated-cards.json");
writeFileSync(out, JSON.stringify(cards, null, 2));

for (const c of cards) {
  console.log(`✓ ${c.slug}  (${c.area}/${c.mode})  본문 ${c.contentMd.length}자, 질문 ${c.questions.length}개`);
}
console.log(`\n→ ${out}`);

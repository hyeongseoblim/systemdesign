// migrated-cards.json 을 API 에 등록 (재실행 안전 — slug 중복은 건너뜀)
// 사용: API_BASE=http://localhost:8080 node tools/import-cards.mjs
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const API_BASE = process.env.API_BASE ?? "http://localhost:8080";
const here = dirname(fileURLToPath(import.meta.url));
const cards = JSON.parse(readFileSync(resolve(here, "migrated-cards.json"), "utf8"));

let ok = 0, skip = 0, fail = 0;
for (const card of cards) {
  const res = await fetch(`${API_BASE}/api/v1/cards`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(card),
  });
  if (res.status === 201) {
    ok++;
    console.log(`✓ 등록: ${card.slug}`);
  } else if (res.status === 409) {
    skip++;
    console.log(`- 건너뜀(이미 존재): ${card.slug}`);
  } else {
    fail++;
    console.error(`✗ 실패(${res.status}): ${card.slug} — ${(await res.text()).slice(0, 200)}`);
  }
}
console.log(`\n등록 ${ok} / 건너뜀 ${skip} / 실패 ${fail}`);
if (fail > 0) process.exit(1);

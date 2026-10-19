# tools — 콘텐츠 마이그레이션 (Phase 5)

기존 정적 학습 HTML 8개를 카드 DB로 이관하는 스크립트.

## 1. 변환 (HTML → 카드 JSON)
```bash
cd tools && npm install && cd ..
node tools/migrate-content.mjs
# → tools/migrated-cards.json 생성 (커밋돼 있으므로 재실행은 원본 수정 시에만)
```

변환 규칙:
- HTML 1개 = 카드 1장 (`publishNow: true`)
- Mermaid 다이어그램 → ` ```mermaid ` 펜스 블록 (프론트에서 다시 렌더됨)
- 표 → GFM 테이블, Callout 박스 → 인용구(제목 굵게)
- Q&A 섹션의 질문들 → `card_questions` (답변 입력은 interactions API로)
- 사이드바/피드백 버튼/다음학습 등 내비게이션 요소는 제거

## 2. 등록 (JSON → API)
API가 떠 있는 곳에서:
```bash
API_BASE=http://localhost:8080 node tools/import-cards.mjs
```
- 재실행 안전: slug 충돌(409)은 "이미 존재"로 건너뜀
- VM에서 하려면 Node 설치 후 실행하거나, 로컬에서 `API_BASE=https://api.<도메인>` 으로 원격 등록

## 참고
- 원본 HTML은 삭제하지 않는다 (GitHub Pages 링크 유지)
- `docs/00-platform-architecture.html`(설계 문서)는 학습 카드가 아니므로 제외

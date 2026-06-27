# jobStudy Web (Phase 3 — 모바일 PWA)

Next.js 15(App Router) 기반 모바일 우선 학습 카드 피드. `apps/api`를 소비한다.

## 기능
- 영역 필터(칩) + 카드 피드 + Cursor "더 보기"
- 카드 상세: 마크다운 본문 + Mermaid 다이어그램 렌더
- 이해도 Q&A (현재 localStorage, Phase 4에서 API 연동)
- PWA: 홈 화면 추가(manifest) + 오프라인 캐시(service worker)

## 로컬 실행
```bash
cd apps/web
cp .env.example .env.local   # NEXT_PUBLIC_API_BASE 확인
npm install
npm run dev                  # http://localhost:3000
```
백엔드(`apps/api`)가 8080에서 떠 있어야 카드가 보인다.

## 빌드
```bash
npm run build && npm start
```

## 환경 변수
| 변수 | 기본값 | 설명 |
|---|---|---|
| `NEXT_PUBLIC_API_BASE` | `http://localhost:8080` | 백엔드 API 주소 |

## 배포 (Phase 4)
- Vercel에 `apps/web`을 루트로 연결, `NEXT_PUBLIC_API_BASE`를 실제 API 도메인으로 설정
- PWA 아이콘(`public/icon-192.png`, `icon-512.png`)은 추후 추가 (없어도 동작)

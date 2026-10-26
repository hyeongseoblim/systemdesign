# jobStudy Web

Next.js 15(App Router) 기반 모바일 우선 학습 카드 피드. `apps/api`를 소비한다.

## 기능
- 영역 필터(칩) + 카드 피드 + Cursor "더 보기"
- 카드 상세: 마크다운 본문 + 세로로 읽는 SVG 다이어그램 이미지(흐름도·시퀀스·문자 도표)
- 이해도 Q&A (현재 localStorage에 저장, API 연동은 향후 과제)
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

## 다이어그램 이미지

현재 129개 카드의 Mermaid 266개와 문자 도표 7개를 미리 생성한 SVG로 표시한다. 가로 흐름도는 세로 방향으로 배치하고 시퀀스는 참여자·메시지·조건 분기를 세로 단계로 표시한다. 넓은 도표는 전체 보기와 겹치는 확대 구간을 본문 아래에 이어 표시한다. [생성·검증 방법](../../docs/diagram-reading.md)을 참고한다.

## 배포
- Vercel에 `apps/web`을 루트로 연결, `NEXT_PUBLIC_API_BASE`를 실제 API 도메인으로 설정
- PWA 아이콘(`public/icon-192.png`, `icon-512.png`)은 추후 추가 (없어도 동작)

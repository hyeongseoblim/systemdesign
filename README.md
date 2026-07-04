# jobStudy — 백엔드 이직 준비 학습 플랫폼

6년차 백엔드 개발자의 이직 준비를 위한 **모바일 우선 학습 카드 플랫폼**. 시스템 디자인·물류 도메인·백엔드 설계를 카드 단위로 학습하고, AI 생성 파이프라인으로 콘텐츠를 지속 확충한다.

> 정적 HTML 학습 노트에서 출발해, **API + PWA + AI 생성** 구조로 전환한 프로젝트다.

## 아키텍처

```
[사용자] → Vercel (Next.js PWA) → Oracle VM (Spring/Kotlin API + PostgreSQL) → Claude API
                apps/web                     apps/api                         (AI 카드 생성)
```

- **`apps/api`** — Spring Boot 3.3 / Kotlin / PostgreSQL / Flyway. 학습 카드 REST API + AI 생성 파이프라인(품질 게이트 3종) + 스케줄러.
- **`apps/web`** — Next.js 15(App Router) 모바일 우선 PWA. 카드 피드·상세(마크다운 + Mermaid 렌더)·오프라인 캐시.
- **`infra`** — Oracle Free Tier(A1.Flex) + Vercel 배포(0원). `docker-compose.yml`, VM 셋업 스크립트.
- **`docs`** — 플랫폼 아키텍처 설계 문서(Phase 0).

## 콘텐츠 모델

학습 콘텐츠는 **DB의 Card**로 관리된다(정적 HTML 아님).

| 테이블 | 역할 |
|---|---|
| `cards` | 카드 본문(`content_md` 마크다운) · area · mode · 난이도 · 상태(DRAFT/PUBLISHED) · source(AI_GENERATED/MANUAL) |
| `card_tags` / `card_questions` | 태그 · 이해도 확인 질문 |
| `curriculum_topics` | AI가 생성할 주제 목록(중복 방지 게이트) |
| `interactions` | 사용자 답변 · 북마크 |

카드 출처는 두 가지다.
1. **수동(MANUAL)** — `apps/api/src/main/resources/content/*.md`(프론트매터 + 마크다운)를 `ContentSeeder`가 부팅 시 slug 기준 멱등 적재. 현재 **7개 영역 47개 카드** 시드.
2. **AI 생성(AI_GENERATED)** — 스케줄러가 `curriculum_topics`를 골라 Claude API로 생성, 품질 게이트 통과 시 발행.

## 학습 영역 (7종)

시스템 디자인 · 물류 도메인 · 백엔드 개발 · 백엔드 아키텍처 · 데이터베이스 · 인프라 · CS 기초.
각 영역별 **코치 에이전트**(`.claude/agents/`)와 학습 모드(`/interview` `/concept` `/design` `/review`)가 정의되어 있다. 상세는 [CLAUDE.md](CLAUDE.md) 참고.

## 로컬 실행

### 백엔드
```bash
# PostgreSQL
docker run -d --name jobstudy-pg -e POSTGRES_DB=jobstudy \
  -e POSTGRES_USER=jobstudy -e POSTGRES_PASSWORD=jobstudy -p 5432:5432 postgres:16

# API (JDK 21 필요)
cd apps/api && ./gradlew bootRun
# Flyway가 스키마 생성 → ContentSeeder가 47개 카드 적재
```
> **주의**: 프로젝트 툴체인은 **JDK 21**이다(Kotlin 1.9.25). JDK 25 등 상위 버전으로는 컴파일되지 않는다.

### 프론트엔드
```bash
cd apps/web && cp .env.example .env.local && npm install && npm run dev
# http://localhost:3000 (API가 8080에 떠 있어야 함)
```

### 한 번에 (Docker Compose)
```bash
cd infra && cp .env.example .env   # DB_PASSWORD / ADMIN_TOKEN / ANTHROPIC_API_KEY 설정
docker compose up -d
```

## 주요 API

| 메서드 | 경로 | 설명 |
|---|---|---|
| `GET` | `/api/v1/cards?area=&mode=&cursor=&limit=20` | 카드 피드(published, keyset 페이지네이션) |
| `GET` | `/api/v1/cards/{id}` | 카드 상세(본문 + 질문) |
| `POST` | `/api/v1/cards` | 카드 수동 생성(MANUAL) |
| `GET` | `/api/v1/health` | 헬스체크 |

자세한 내용은 [apps/api/README.md](apps/api/README.md), [apps/web/README.md](apps/web/README.md), [infra/README.md](infra/README.md) 참고.

## 라이선스

[MIT License](LICENSE)

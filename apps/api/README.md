# jobStudy API (Phase 1 — 백엔드 코어)

Spring Boot 3.3 / Kotlin / PostgreSQL / Flyway 기반 학습 카드 REST API.

## 로컬 실행

### 1. PostgreSQL 띄우기 (Docker)
```bash
docker run -d --name jobstudy-pg \
  -e POSTGRES_DB=jobstudy \
  -e POSTGRES_USER=jobstudy \
  -e POSTGRES_PASSWORD=jobstudy \
  -p 5432:5432 postgres:16
```

### 2. 앱 실행
```bash
cd apps/api
./gradlew bootRun
```
Flyway가 `V1__init.sql`을 자동 적용한다. (`gradlew` 래퍼 jar가 없으면 `gradle wrapper --gradle-version 8.10.2` 로 생성)

### 3. 환경 변수
| 변수 | 기본값 | 설명 |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/jobstudy` | DB 접속 URL |
| `DB_USER` / `DB_PASSWORD` | `jobstudy` | DB 계정 |
| `PORT` | `8080` | 서버 포트 |
| `CORS_ORIGINS` | `http://localhost:3000` | 허용 오리진(쉼표 구분) |

## API (Phase 1)

| 메서드 | 경로 | 설명 |
|---|---|---|
| `GET` | `/api/v1/health` | 헬스체크 |
| `GET` | `/api/v1/cards?area=&mode=&cursor=&limit=20` | 카드 피드 (published만, keyset 페이지네이션) |
| `GET` | `/api/v1/cards/{id}` | 카드 상세 |
| `POST` | `/api/v1/cards` | 카드 수동 생성 (MANUAL) |

### 예시
```bash
# 카드 생성 + 즉시 게시
curl -X POST http://localhost:8080/api/v1/cards \
  -H 'Content-Type: application/json' \
  -d '{
    "area": "SYSTEM_DESIGN",
    "mode": "CONCEPT",
    "title": "Consistent Hashing 기초",
    "slug": "consistent-hashing-basics",
    "summary": "노드 추가/제거 시 키 이동 최소화",
    "contentMd": "# Consistent Hashing\n링 구조로...",
    "tags": ["hashing", "distributed"],
    "questions": ["가상 노드는 왜 필요한가?"],
    "publishNow": true
  }'

# 피드 조회
curl 'http://localhost:8080/api/v1/cards?area=SYSTEM_DESIGN&limit=20'
```

## AI 생성 파이프라인 (Phase 2)

매일 스케줄러가 Claude API로 학습 카드를 자동 생성한다. 품질 게이트 3종 적용:

1. **중복 방지** — `curriculum_topics`에서 `generated=false`인 주제만 생성
2. **자가 검증** — 생성 직후 2차 LLM 호출로 사실성·구조 평가 → `quality_score`. 임계치(기본 70) 미달이면 `DRAFT`로 보류
3. **예산 캡** — 일일 카드 수(기본 3) + 일일 토큰(기본 200k) 상한 초과 시 중단

### 생성 관련 환경 변수
| 변수 | 기본값 | 설명 |
|---|---|---|
| `ANTHROPIC_API_KEY` | (없음) | **필수** — 없으면 배치 자동 스킵 |
| `ANTHROPIC_MODEL` | `claude-sonnet-4-6` | 생성 모델 |
| `GEN_ENABLED` | `true` | 배치 on/off |
| `GEN_CRON` | `0 0 9 * * *` | 실행 시각 (cron) |
| `GEN_ZONE` | `Asia/Seoul` | 타임존 |
| `GEN_DAILY_CARDS` | `3` | 일일 생성 상한 |
| `GEN_DAILY_TOKENS` | `200000` | 일일 토큰 상한 |
| `GEN_QUALITY_THRESHOLD` | `70` | 자가검증 통과 점수 |

### 운영 엔드포인트
| 메서드 | 경로 | 설명 |
|---|---|---|
| `POST` | `/api/v1/admin/generate` | 배치 수동 트리거 (게이트 모두 적용) |
| `GET` | `/api/v1/admin/drafts?limit=20` | 검수 대기 draft 목록 |

```bash
# 키 주입 후 수동 트리거
export ANTHROPIC_API_KEY=sk-ant-...
curl -X POST http://localhost:8080/api/v1/admin/generate
# → {"attempted":3,"published":2,"drafted":1,"failed":0}
```

> ⚠️ admin 엔드포인트는 Phase 4에서 토큰 인증으로 보호 예정.

## 다음 단계 (Phase 3)
- Next.js PWA 모바일 카드 피드 (이 API 소비)

# jobStudy API

Spring Boot 3.5.16 / Kotlin 2.3 / JDK 25 / PostgreSQL / Flyway 기반 학습 카드 REST API.

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
Flyway가 `V1__init.sql`부터 현재 마이그레이션까지 자동 적용한다. Gradle Wrapper는 저장소에 포함돼 있으므로 별도 Gradle 설치는 필요 없다.

### 3. 환경 변수
| 변수 | 기본값 | 설명 |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/jobstudy` | DB 접속 URL |
| `DB_USER` / `DB_PASSWORD` | `jobstudy` | DB 계정 |
| `PORT` | `8080` | 서버 포트 |
| `CORS_ORIGINS` | `http://localhost:3000` | 허용 오리진(쉼표 구분) |
| `DB_POOL_MAX_SIZE` / `DB_POOL_MIN_IDLE` | `5` / `0` | Cloud Run/Neon용 HikariCP 연결 풀 크기 |

## API

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

## AI 생성 파이프라인

생성 기능을 활성화하면 스케줄러가 Claude API로 학습 카드를 생성한다. Cloud Run은 scale-to-zero 환경에서 내부 스케줄러 실행을 보장하지 않으므로, 운영에서는 Cloud Scheduler가 관리자 생성 엔드포인트를 호출하도록 구성한다. 품질 게이트 3종 적용:

1. **중복 방지** — `curriculum_topics`에서 `resolution_status=PENDING`인 주제만 생성. 수동 카드가 연결한 주제도 생성 대상에서 제외
2. **자가 검증** — 생성 직후 2차 LLM 호출로 사실성·구조 평가 → `quality_score`. 임계치(기본 70) 미달이면 `DRAFT`로 보류
3. **예산 캡** — 일일 카드 수(기본 3) + 일일 토큰(기본 200k) 상한 초과 시 중단

### 생성 관련 환경 변수
| 변수 | 기본값 | 설명 |
|---|---|---|
| `ANTHROPIC_API_KEY` | (없음) | **필수** — 없으면 배치 자동 스킵 |
| `ANTHROPIC_MODEL` | `claude-sonnet-4-6` | 생성 모델 |
| `GEN_ENABLED` | `false` | 배치 on/off. Cloud Scheduler 준비 전에는 `false` 유지 |
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

> 운영 쓰기 API(`/api/v1/admin/**`, `POST` 등 `/api/v1/cards/**`)는 `X-Admin-Token` 인증이 필요하다. `ADMIN_TOKEN`이 비어 있으면 안전하게 전부 차단된다.

## 콘텐츠 운영

수동 카드의 소스는 `src/main/resources/content/*.md`이며, 부팅 시 `ContentSeeder`가 slug 기준으로 멱등 적재한다. 소스 기준 현재 100개 카드가 있다. 선택적인 `topicKey` 프론트매터를 넣으면 해당 커리큘럼 주제가 `MANUAL` 상태로 연결되어 AI 중복 생성을 막는다.

콘텐츠 계약은 저장소 루트에서 `scripts/check-content.sh`로 검사한다.

AI 생성 대상과 수동 카드의 중복 방지·확장 순서는 [콘텐츠 확장 설계](../../docs/content-expansion-plan.md)를 따른다.

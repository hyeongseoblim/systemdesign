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

## 다음 단계 (Phase 2)
- 스케줄러 + Claude API 카드 생성기
- 품질 게이트 3종 (중복 방지 / 자가 검증 / 예산 캡)
- `curriculum_topics` 기반 주제 큐레이션

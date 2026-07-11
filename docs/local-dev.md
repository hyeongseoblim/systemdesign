# 로컬 개발 환경 세팅

클라우드 배포 없이 전부 로컬에서 띄우는 가이드. 구조는 세 조각이다.

```
[브라우저] → Next.js dev 서버 (:3000) → Spring Boot API (:8080) → PostgreSQL (도커, :5432)
```

## 0. 요구사항

| 도구 | 버전 | 확인 |
|---|---|---|
| Docker | 아무 최신 | `docker --version` |
| JDK | **25** | `java -version` |
| Node.js | 18.18+ (권장 20+) | `node --version` |

> API 는 Gradle Wrapper(`gradlew`)를 쓰므로 Gradle 별도 설치는 불필요하다.

## 1. 원샷 실행 (권장)

```bash
scripts/local-dev.sh up      # Postgres + API + 웹 전부 기동
scripts/local-dev.sh status  # 상태 확인
scripts/local-dev.sh down    # 전부 종료 (DB 데이터는 유지)
```

- 첫 실행은 Gradle 의존성/Next 패키지 다운로드로 수 분 걸린다.
- 로그: `.local/api.log`, `.local/web.log`
- 완료 후 http://localhost:3000 에서 카드 피드 확인.

## 2. 수동 실행 (터미널 3개)

핫 리로드로 개발할 때는 각각 포그라운드로 띄우는 게 편하다.

```bash
# ① PostgreSQL — 도커로 DB만
cd infra && docker compose -f docker-compose.local.yml up -d

# ② API — Flyway 마이그레이션 + ContentSeeder(카드 시드) 자동 실행
cd apps/api && ./gradlew bootRun
curl http://localhost:8080/api/v1/health   # {"status":"UP"}

# ③ 웹
cd apps/web
cp .env.example .env.local                 # NEXT_PUBLIC_API_BASE=http://localhost:8080
npm ci && npm run dev                      # http://localhost:3000
```

## 3. 무엇이 자동으로 되나

부팅 순서대로:

1. **Flyway** 가 `db/migration/V1__init.sql`, `V2__generation.sql` 마이그레이션 실행 (테이블 + 커리큘럼 시드 12건).
2. **ContentSeeder** 가 `apps/api/src/main/resources/content/*.md` 를 slug 기준 멱등으로 적재 — 학습 카드 59개가 발행(`source=MANUAL`) 상태로 들어간다. 재기동해도 중복 생성되지 않는다.
3. 웹 피드(`/`)가 `GET /api/v1/cards` 로 카드를 노출한다.

## 4. 선택 설정 (환경변수)

전부 기본값으로 동작하며, 필요할 때만 API 실행 전에 export 한다.

| 변수 | 기본값 | 용도 |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/jobstudy` | 다른 DB 쓸 때 |
| `DB_USER` / `DB_PASSWORD` | `jobstudy` / `jobstudy` | 〃 |
| `PORT` | `8080` | API 포트 |
| `CORS_ORIGINS` | `http://localhost:3000` | 웹 포트를 바꿨다면 함께 변경 |
| `ANTHROPIC_API_KEY` | (빈 값) | **비어 있으면 AI 카드 생성 배치는 자동 스킵** — 로컬 학습 용도로는 없어도 됨 |
| `GEN_ENABLED` | `true` | 생성 배치 자체를 끄려면 `false` |
| `ADMIN_TOKEN` | (빈 값) | admin 엔드포인트 쓸 때만 |
| `jobstudy.seed.content.enabled` | `true` | 카드 시드 끄기 (`-Djobstudy.seed.content.enabled=false`) |

## 5. 자주 겪는 문제

- **5432 포트 충돌**: 로컬에 Postgres 가 이미 떠 있으면 `docker-compose.local.yml` 의 ports 를 `"55432:5432"` 로 바꾸고 `DB_URL=jdbc:postgresql://localhost:55432/jobstudy` 로 API 를 띄운다.
- **웹에서 카드가 안 보임**: `apps/web/.env.local` 의 `NEXT_PUBLIC_API_BASE` 확인 → 브라우저 콘솔에 CORS 에러가 있으면 API 의 `CORS_ORIGINS` 와 웹 주소가 일치하는지 확인.
- **`ddl-auto: validate` 오류**: 스키마와 엔티티 불일치. 마이그레이션 파일을 수정했다면 DB 볼륨을 초기화한다 — `docker compose -f infra/docker-compose.local.yml down -v` 후 재기동.
- **DB 데이터 완전 초기화**: 위와 동일 (`down -v` 가 볼륨까지 삭제).

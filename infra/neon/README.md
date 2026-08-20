# Neon PostgreSQL 상태 점검

이 디렉토리의 스크립트는 기존 Neon 데이터베이스를 **읽기 전용으로 확인**한다. 스키마 변경은 직접 실행하지 않고, Cloud Run API가 시작할 때 Flyway가 적용한다.

## GCP Secret Manager 값을 사용하는 경우

시크릿 값을 화면이나 파일로 출력하지 않고 현재 셸 환경에만 주입한다.

```bash
export DB_URL="$(gcloud secrets versions access latest --secret=jobstudy-db-url)"
export DB_USER="$(gcloud secrets versions access latest --secret=jobstudy-db-user)"
export DB_PASSWORD="$(gcloud secrets versions access latest --secret=jobstudy-db-password)"

infra/neon/check-db.sh

unset DB_URL DB_USER DB_PASSWORD PGPASSWORD
```

## Neon 연결 정보를 직접 사용하는 경우

```bash
export DB_URL='jdbc:postgresql://<neon-host>/<database>?sslmode=require'
export DB_USER='<neon-user>'
printf 'Neon DB password: ' >&2
IFS= read -rs DB_PASSWORD
printf '\n' >&2
export DB_PASSWORD

infra/neon/check-db.sh

unset DB_URL DB_USER DB_PASSWORD PGPASSWORD
```

점검 항목은 다음과 같다.

- 실제 접속 DB·Role·PostgreSQL 버전
- `flyway_schema_history` 존재 여부와 V1~V5 적용 결과
- MANUAL/AI 및 DRAFT/PUBLISHED별 카드 수
- `PENDING`, `MANUAL`, `AI_DRAFT`, `AI_PUBLISHED`, `SKIPPED`별 커리큘럼 수

신규 코드가 배포되고 `ContentSeeder`가 한 번 실행된 DB라면 수동 카드 114개와 `MANUAL` 커리큘럼 55개가 기준선이다. AI 생성 이력이 있으면 `PENDING` 수는 소스 기준선 314개보다 적을 수 있다.

#!/usr/bin/env bash
# jobStudy API 를 Google Cloud Run 에 배포한다.
#
# 사전 준비:
#   1) gcloud CLI 설치 + `gcloud auth login`
#   2) Neon 에서 Postgres 생성 (무료) → pooled JDBC URL 확보
#   3) cp .env.cloudrun.example .env.cloudrun && nano .env.cloudrun
#
# 사용:
#   cd infra && bash deploy-cloudrun.sh
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE=".env.cloudrun"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE 이 없습니다. 먼저 만드세요:"
  echo "   cp .env.cloudrun.example .env.cloudrun && nano .env.cloudrun"
  exit 1
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE:-jobstudy-api}"

for v in PROJECT_ID DB_URL DB_USER DB_PASSWORD ADMIN_TOKEN; do
  if [ -z "${!v:-}" ]; then echo "❌ $ENV_FILE 의 $v 가 비었습니다."; exit 1; fi
done

echo "==> 1/4 프로젝트 설정: $PROJECT_ID / $REGION"
gcloud config set project "$PROJECT_ID" >/dev/null

echo "==> 2/4 필요한 API 활성화 (이미 켜져 있으면 즉시 통과)"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project "$PROJECT_ID"

# 환경 변수는 --set-env-vars 대신 --env-vars-file 로 넘긴다.
# --set-env-vars 는 콤마를 구분자로 쓰기 때문에 CORS_ORIGINS(콤마 다중 도메인)나
# 특수문자를 품은 DB_PASSWORD 에서 값이 잘려 나간다. YAML 파일 방식은 그런 파싱이 없다.
# mktemp -t 는 macOS(BSD)와 Linux(GNU)의 해석이 달라 템플릿을 명시한다.
ENV_YAML="$(mktemp "${TMPDIR:-/tmp}/jobstudy-env.XXXXXX")"
# 시크릿이 담기므로 권한을 좁히고 스크립트 종료 시 반드시 지운다.
chmod 600 "$ENV_YAML"
trap 'rm -f "$ENV_YAML"' EXIT INT TERM

# YAML 작은따옴표 스칼라는 내부의 ' 만 '' 로 이스케이프하면 나머지는 전부 리터럴이다.
put() { printf "%s: '%s'\n" "$1" "$(printf '%s' "$2" | sed "s/'/''/g")" >> "$ENV_YAML"; }

put DB_URL            "$DB_URL"
put DB_USER           "$DB_USER"
put DB_PASSWORD       "$DB_PASSWORD"
put ADMIN_TOKEN       "$ADMIN_TOKEN"
put ANTHROPIC_API_KEY "${ANTHROPIC_API_KEY:-}"
put ANTHROPIC_MODEL   "${ANTHROPIC_MODEL:-claude-sonnet-4-6}"
put CORS_ORIGINS      "${CORS_ORIGINS:-http://localhost:3000}"
put GEN_ENABLED       "${GEN_ENABLED:-false}"
put DB_POOL_MAX       "${DB_POOL_MAX:-5}"
put DB_POOL_MIN       "${DB_POOL_MIN:-1}"
# JVM 튜닝 — 콜드 스타트 우선.
#   MaxRAMPercentage=60 : 1Gi 컨테이너에서 heap 약 600MB. 나머지는 메타스페이스·스레드 스택 몫.
#                         70% 로 올리면 non-heap 과 합쳐 1Gi 를 넘겨 OOM kill 위험이 있다.
#   UseSerialGC         : vCPU 1개에서는 G1 의 백그라운드 스레드가 오히려 손해.
#   TieredStopAtLevel=1 : C2 JIT 를 끄고 C1 만 사용 → 기동은 빨라지고 최대 처리량은 떨어진다.
#                         사용자 1명 수준의 부하에서는 명백히 남는 장사.
put JAVA_OPTS "-XX:MaxRAMPercentage=60 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Dspring.jmx.enabled=false"

echo "==> 3/4 빌드 & 배포 (최초 빌드는 5분 내외 소요)"
gcloud run deploy "$SERVICE" \
  --source ../apps/api \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3 \
  --concurrency 40 \
  --cpu-boost \
  --timeout 900 \
  --env-vars-file "$ENV_YAML"

URL=$(gcloud run services describe "$SERVICE" --region "$REGION" \
        --project "$PROJECT_ID" --format 'value(status.url)')

echo "==> 4/4 헬스 체크: $URL"
if curl -sf --max-time 90 "$URL/api/v1/health" >/dev/null; then
  echo "✅ 배포 완료"
  echo
  echo "  API_BASE          : $URL"
  echo "  카드 피드 확인    : curl '$URL/api/v1/cards?limit=3'"
  echo "  생성 수동 트리거  : curl -X POST -H 'X-Admin-Token: $ADMIN_TOKEN' '$URL/api/v1/admin/generate'"
  echo
  echo "  다음 단계:"
  echo "   1) Vercel 환경변수 NEXT_PUBLIC_API_BASE 를 위 URL 로 설정"
  echo "   2) .env.cloudrun 의 CORS_ORIGINS 를 실제 Vercel 도메인으로 좁힌 뒤 재배포"
  echo "   3) GitHub 레포 Secrets 에 API_BASE / ADMIN_TOKEN 등록 (데일리 생성 크론)"
else
  echo "⚠️ 헬스 체크 실패. 로그 확인:"
  echo "   gcloud run services logs read $SERVICE --region $REGION --limit 100"
  exit 1
fi

#!/usr/bin/env bash
# Cloud Run API 배포. 실행 전 README의 Secret Manager 준비를 마쳐야 한다.
# 예: infra/cloudrun/deploy.sh --project my-gcp-project --cors-origins https://my-app.vercel.app
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_ID=""
REGION="asia-northeast3"
CORS_ORIGINS=""
SERVICE_NAME="jobstudy-api"
RUNTIME_SERVICE_ACCOUNT="jobstudy-api-runtime"

usage() {
  cat <<'EOF'
Usage:
  infra/cloudrun/deploy.sh --project PROJECT_ID --cors-origins https://YOUR_APP.vercel.app [options]

Options:
  --region REGION       Cloud Run region (default: asia-northeast3, Seoul)
  --service NAME        Cloud Run service name (default: jobstudy-api)
  -h, --help            Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) PROJECT_ID="${2:?missing project id}"; shift 2 ;;
    --region) REGION="${2:?missing region}"; shift 2 ;;
    --service) SERVICE_NAME="${2:?missing service name}"; shift 2 ;;
    --cors-origins) CORS_ORIGINS="${2:?missing CORS origins}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ -z "$PROJECT_ID" ] || [ -z "$CORS_ORIGINS" ]; then
  echo "--project and --cors-origins are required." >&2
  usage >&2
  exit 1
fi
command -v gcloud >/dev/null 2>&1 || {
  echo "gcloud CLI is required: https://cloud.google.com/sdk/docs/install" >&2
  exit 1
}

for secret in jobstudy-db-url jobstudy-db-user jobstudy-db-password jobstudy-admin-token; do
  gcloud secrets describe "$secret" --project "$PROJECT_ID" >/dev/null 2>&1 || {
    echo "Missing Secret Manager secret: $secret" >&2
    echo "Create it first using infra/cloudrun/README.md." >&2
    exit 1
  }
done

RUNTIME_SERVICE_ACCOUNT_EMAIL="$RUNTIME_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
gcloud iam service-accounts describe "$RUNTIME_SERVICE_ACCOUNT_EMAIL" --project "$PROJECT_ID" >/dev/null 2>&1 || {
  echo "Missing runtime service account: $RUNTIME_SERVICE_ACCOUNT_EMAIL" >&2
  echo "Create it and grant Secret Manager access using infra/cloudrun/README.md." >&2
  exit 1
}

gcloud run deploy "$SERVICE_NAME" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --source "$ROOT_DIR/apps/api" \
  --allow-unauthenticated \
  --port 8080 \
  --cpu 1 \
  --memory 1Gi \
  --concurrency 20 \
  --min-instances 0 \
  --max-instances 1 \
  --timeout 300 \
  --cpu-throttling \
  --service-account "$RUNTIME_SERVICE_ACCOUNT_EMAIL" \
  --set-env-vars "^@^CORS_ORIGINS=$CORS_ORIGINS@GEN_ENABLED=false@DB_POOL_MAX_SIZE=5@DB_POOL_MIN_IDLE=0" \
  --set-secrets "DB_URL=jobstudy-db-url:latest,DB_USER=jobstudy-db-user:latest,DB_PASSWORD=jobstudy-db-password:latest,ADMIN_TOKEN=jobstudy-admin-token:latest"

echo
echo "Deployment complete. Verify with:"
echo "  gcloud run services describe $SERVICE_NAME --project $PROJECT_ID --region $REGION --format='value(status.url)'"

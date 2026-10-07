#!/usr/bin/env bash
# GCP Cloud Shell에서 실행. 배포하지 않고 GitHub OIDC/IAM만 구성한다.
set -euo pipefail
PROJECT_ID=jobstudy-14798
REGION="${1:?사용법: bash setup-github-oidc.sh CLOUD_RUN_REGION ARTIFACT_REPOSITORY}"
REPOSITORY="${2:?기존 Artifact Registry 저장소 이름이 필요합니다}"
SA_NAME=github-jobstudy-deployer
POOL=github-jobstudy
PROVIDER=github
export CLOUDSDK_CORE_PROJECT="$PROJECT_ID"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

gcloud run services describe jobstudy-api --region "$REGION" --format='value(status.url)'
gcloud artifacts repositories describe "$REPOSITORY" --location "$REGION" --format='value(format)'

gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com artifactregistry.googleapis.com run.googleapis.com

if ! gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" --display-name='GitHub jobstudy deployer'
fi
if ! gcloud iam workload-identity-pools describe "$POOL" --location=global >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL" --location=global --display-name='GitHub jobstudy'
fi
if gcloud iam workload-identity-pools providers describe "$PROVIDER" --location=global --workload-identity-pool="$POOL" >/dev/null 2>&1; then
  echo '기존 OIDC provider가 있습니다. 기존 설정을 덮어쓰지 않습니다. 가이드의 issuer와 attribute 조건이 일치하는지 확인하세요.' >&2
  exit 1
fi
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --location=global --workload-identity-pool="$POOL" \
  --issuer-uri='https://token.actions.githubusercontent.com' \
  --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository' \
  --attribute-condition="assertion.repository == 'hyeongseoblim/systemdesign' && assertion.ref == 'refs/heads/main' && assertion.sub == 'repo:hyeongseoblim/systemdesign:environment:production'"

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL/attribute.repository/hyeongseoblim/systemdesign"

gcloud run services add-iam-policy-binding jobstudy-api --region "$REGION" \
  --member="serviceAccount:$SA_EMAIL" --role=roles/run.developer
gcloud artifacts repositories add-iam-policy-binding "$REPOSITORY" --location "$REGION" \
  --member="serviceAccount:$SA_EMAIL" --role=roles/artifactregistry.writer

RUNTIME_SA="$(gcloud run services describe jobstudy-api --region "$REGION" --format='value(spec.template.spec.serviceAccountName)')"
test -n "$RUNTIME_SA"
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_SA" \
  --member="serviceAccount:$SA_EMAIL" --role=roles/iam.serviceAccountUser

printf 'GCP_REGION=%s\nGCP_ARTIFACT_REPOSITORY=%s\nGCP_WORKLOAD_IDENTITY_PROVIDER=projects/%s/locations/global/workloadIdentityPools/%s/providers/%s\nGCP_DEPLOY_SERVICE_ACCOUNT=%s\n' \
  "$REGION" "$REPOSITORY" "$PROJECT_NUMBER" "$POOL" "$PROVIDER" "$SA_EMAIL"

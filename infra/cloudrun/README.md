# Cloud Run + Neon 배포

Spring API는 Cloud Run에서 실행하고, Neon PostgreSQL을 사용한다.
프론트는 기존대로 Vercel(`apps/web`)에 배포한다.

```
Vercel (Next.js) -> Cloud Run (Spring API) -> Neon (PostgreSQL)
```

## 1. Neon 데이터베이스 만들기

Neon에서 새 프로젝트와 데이터베이스를 만든다. 연결 문자열은 **JDBC 형식**으로 만들어 Secret Manager에 넣는다.

```text
jdbc:postgresql://<neon-host>/<database>?sslmode=require
```

Neon의 pooled connection URL을 쓸 수 있으며, 이 프로젝트의 Hikari 풀은 최대 5개로 제한돼 있다.

## 2. GCP 준비

프로젝트 생성과 결제 계정 연결 후, 로컬에서 로그인하고 필요한 API를 켠다.

```bash
gcloud auth login
gcloud config set project <PROJECT_ID>
gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com
```

비용 예산 알림도 먼저 설정한다. Cloud Run은 무료 할당량이 있지만 결제 계정이 필요하며, 이를 넘는 사용량은 과금될 수 있다.

## 3. 배포 시크릿 만들기

시크릿 값은 Git, Vercel 환경 변수, 명령 히스토리에 넣지 않는다. 아래 명령은 입력을 표준 입력으로 넘긴다.

```bash
gcloud secrets create jobstudy-db-url --replication-policy=automatic
gcloud secrets create jobstudy-db-user --replication-policy=automatic
gcloud secrets create jobstudy-db-password --replication-policy=automatic
gcloud secrets create jobstudy-admin-token --replication-policy=automatic

printf '%s' 'jdbc:postgresql://<neon-host>/<database>?sslmode=require' | gcloud secrets versions add jobstudy-db-url --data-file=-
printf '%s' '<neon-user>' | gcloud secrets versions add jobstudy-db-user --data-file=-
printf '%s' '<neon-password>' | gcloud secrets versions add jobstudy-db-password --data-file=-
openssl rand -hex 32 | tr -d '\n' | gcloud secrets versions add jobstudy-admin-token --data-file=-
```

Cloud Run이 실행 중에 시크릿을 읽을 전용 서비스 계정도 만든다.

```bash
PROJECT_ID="$(gcloud config get-value project)"
RUNTIME_SA="jobstudy-api-runtime@$PROJECT_ID.iam.gserviceaccount.com"
gcloud iam service-accounts create jobstudy-api-runtime --display-name="jobStudy Cloud Run runtime"

for SECRET in jobstudy-db-url jobstudy-db-user jobstudy-db-password jobstudy-admin-token; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:$RUNTIME_SA" \
    --role="roles/secretmanager.secretAccessor"
done
```

## 4. API 배포

Vercel 도메인이 아직 없다면 임시 도메인으로 배포한 뒤, 실제 도메인으로 다시 실행한다.

```bash
infra/cloudrun/deploy.sh \
  --project <PROJECT_ID> \
  --cors-origins https://<your-vercel-project>.vercel.app
```

스크립트는 소스를 Cloud Build로 빌드하고 1 vCPU/1GiB, 최소 인스턴스 0, 최대 1인 Cloud Run 서비스를 만든다. `GEN_ENABLED=false`로 고정해 AI API 비용이 의도치 않게 발생하지 않도록 한다.

배포 URL을 확인하고 health endpoint를 호출한다.

```bash
API_URL="$(gcloud run services describe jobstudy-api --region asia-northeast3 --format='value(status.url)')"
curl "$API_URL/api/v1/health"
curl "$API_URL/api/v1/cards?limit=1"
```

첫 요청에서는 컨테이너와 Neon이 모두 깨어나므로 응답이 늦을 수 있다.

## 5. Vercel 연결

Vercel에서 Root Directory를 `apps/web`으로 설정하고 다음 환경 변수를 추가한다.

```text
NEXT_PUBLIC_API_BASE=https://<cloud-run-url>
```

Vercel 배포 주소가 확정되면 `deploy.sh --cors-origins`의 값도 그 주소로 다시 배포한다. Preview 배포도 쓸 경우 쉼표로 여러 origin을 전달할 수 있다.

## 운영 메모

- `POST`, `PUT`, `PATCH`, `DELETE`의 `/api/v1/cards/**`와 `/api/v1/admin/**`은 `X-Admin-Token`이 필요하다.
- Cloud Run의 최소 인스턴스가 0이면 앱이 내려가 있는 시간에는 Spring `@Scheduled` 작업이 실행되지 않는다. AI 일일 생성을 사용하려면 Cloud Scheduler가 `/api/v1/admin/generate`를 호출하도록 별도로 구성해야 한다.
- Neon Free의 저장소와 컴퓨트 한도를 주기적으로 확인하고, 카드 데이터는 별도로 `pg_dump` 백업한다.

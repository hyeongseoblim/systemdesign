# 기존 Cloud Run을 GitHub Actions에서 배포하기

대상은 GCP `jobstudy-14798`의 기존 `jobstudy-api` 서비스다. Vercel `jobstudy`는 기존 Git 연결을 계속 사용한다. Neon 프로젝트·DB·시크릿은 새로 만들지 않는다.

워크플로 `.github/workflows/deploy-api.yml`은 `main`에서 수동으로 실행한다. JDK 25 빌드·테스트 후 GitHub OIDC로 인증하고 이미지를 빌드·push하여 기존 서비스에 배포한다. 서비스 환경변수, 시크릿 참조, 런타임 계정, 리소스 한도, 공개 접근 IAM은 수정하지 않는다. 트래픽은 새 리비전 100%로 전환한다. 기존 트래픽이 분할되거나 태그가 있으면 실행을 중단한다.

새 API가 시작되면 기존 코드의 Flyway와 ContentSeeder가 실행된다. DB 마이그레이션이 포함된 변경은 별도로 검토해야 한다. 이미지 롤백만으로 DB 변경까지 되돌아가지는 않는다. Artifact Registry 저장소·네트워크 비용은 기존 GCP 과금 정책에 따른다.

## 1. GCP에서 두 값 확인

1. https://console.cloud.google.com/run?project=jobstudy-14798 에서 `jobstudy-api`를 선택하고 **리전**을 기록한다. URL 문자열로 리전을 추측하지 않는다.
2. https://console.cloud.google.com/artifacts?project=jobstudy-14798 에서 기존 API 이미지가 있는 **Docker 저장소 이름**을 기록한다. 아래 구성은 저장소와 Cloud Run이 같은 리전에 있을 때 사용한다. 다르면 워크플로에 별도 registry 리전을 추가해야 한다.

## 2. Cloud Shell에서 키 없는 인증 구성

아래 명령을 모은 `infra/cloudrun/setup-github-oidc.sh`도 준비되어 있다. Cloud Shell에 파일을 업로드한 뒤 `bash setup-github-oidc.sh 실제리전 기존저장소이름`으로 실행할 수 있다. 이 스크립트는 OIDC/IAM을 구성하며 API를 배포하지 않는다. 기존 OIDC provider가 있으면 덮어쓰지 않고 중단한다.

GCP 콘솔 오른쪽 위의 **Cloud Shell 활성화**를 누른다. 아래 명령은 GCP IAM 리소스를 생성하고 배포 권한을 부여한다. 기존에 같은 이름의 리소스가 있으면 해당 단계는 건너뛰고 설정을 먼저 확인한다. 조직 정책 때문에 권한이 거부되면 프로젝트 관리자에게 요청한다. JSON 키는 생성하지 않는다.

먼저 두 값을 실제 확인한 값으로 바꾼다.

```bash
set -euo pipefail
PROJECT_ID=jobstudy-14798
REGION=실제_Cloud_Run_리전
REPOSITORY=실제_Artifact_Registry_저장소_이름
SA_NAME=github-jobstudy-deployer
POOL=github-jobstudy
PROVIDER=github
gcloud config set project "$PROJECT_ID"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

gcloud run services describe jobstudy-api --region "$REGION" --format='value(status.url)'
gcloud artifacts repositories describe "$REPOSITORY" --location "$REGION" --format='value(format)'
```

API URL이 기존 운영 주소이고 저장소 format이 `DOCKER`인지 확인한 뒤 실행한다.

```bash
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com artifactregistry.googleapis.com run.googleapis.com

gcloud iam service-accounts create "$SA_NAME" --display-name='GitHub jobstudy deployer'
gcloud iam workload-identity-pools create "$POOL" --location=global --display-name='GitHub jobstudy'
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
```

마지막 출력은 비밀값이 아닌 공개 설정값이므로 GitHub 변수에 등록하면 된다.

## 3. GitHub에 설정 등록

1. https://github.com/hyeongseoblim/systemdesign/settings/environments 를 연다.
2. **New environment**에서 `production`을 만든다. 이미 있다면 기존 환경을 연다.
3. 사용 가능한 경우 Deployment branches를 `main`으로 제한하고 승인자를 지정한다.
4. **Environment variables → Add environment variable**에 아래 네 값을 등록한다.

| 이름 | 값 |
|---|---|
| `GCP_REGION` | 확인한 Cloud Run 리전 |
| `GCP_ARTIFACT_REPOSITORY` | 기존 Docker 저장소 이름 |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Cloud Shell 출력의 `projects/숫자/locations/global/workloadIdentityPools/github-jobstudy/providers/github` |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | `github-jobstudy-deployer@jobstudy-14798.iam.gserviceaccount.com` |

GitHub Secrets에 DB 비밀번호, Neon 키, GCP JSON 키를 등록할 필요는 없다.

## 4. 첫 실행

워크플로를 검토해서 `main`에 반영한 뒤 GitHub **Actions → Deploy existing API → Run workflow → main**을 선택한다. 성공하면 API health와 카드 조회 검증 결과가 실행 요약에 나온다. GCP IAM 반영에는 시간이 걸릴 수 있으므로 인증 실패 시 실행 로그를 확인한다.

배포 실패 시 기존 서비스의 리비전과 트래픽을 확인한다. 자동 롤백은 하지 않는다. 필요하면 Cloud Run 리비전 화면에서 이전 리비전으로 트래픽을 되돌린다. DB 변경은 별도로 확인해야 한다.

## 현재 검증 범위

파일 작성·로컬 구문 검증과 GCP IAM 구성·GitHub 변수 등록·원격 첫 실행은 별개다. 현재 원격 인증 구성과 배포는 수행하지 않았다.

## 이 채팅에서 배포 실행·완료 확인

환경 설정의 네트워크 시크릿에 `GH_TOKEN`을 등록한다. GitHub fine-grained token의 Resource owner는 `hyeongseoblim`, Repository access는 `systemdesign`만 선택하고 Repository permissions의 Actions를 Read and write로 설정한다. Metadata 읽기 권한은 기본 포함된다. JSON 키나 DB 비밀번호는 필요 없다. 토큰은 채팅이나 파일에 넣지 않는다. 만료 시 환경의 시크릿 값만 갱신한다.

환경 설정의 관리 화면에서 시크릿 이름과 대상 변수는 `GH_TOKEN`, 허용 대상 도메인은 `api.github.com`으로 설정한다. 토큰 값은 해당 보안 입력란에 넣고 저장·게시한다.

인증을 적용한 환경에서 다음 명령으로 API 배포 요청, 해당 요청의 실행 완료 대기, 운영 API health·카드 상세·웹 응답 확인을 수행한다.

```bash
cd /workspace/systemdesign
python3 scripts/deploy-production.py
```

프로세스는 15초마다 진행 상태를 출력하고 40분 후 타임아웃 처리한다. 실행 실패나 타임아웃을 배포 성공으로 보고하지 않는다. 타임아웃 후에는 실행 URL을 확인하고 중복 배포 전에 상태를 조회한다. 웹 응답 검사는 Vercel 배포 버전과 커밋 일치를 증명하지 않는다. 웹 코드 변경을 배포하는 작업에서는 Vercel Git 배포의 대상 커밋과 완료 결과도 별도로 확인한다.

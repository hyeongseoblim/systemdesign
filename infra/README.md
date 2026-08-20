# 배포 — Cloud Run + Neon Free + Vercel

Oracle 인스턴스를 만들 수 없는 현재 기본 구성이다. 개인 프로젝트의 소규모 사용량에서는 각
서비스의 무료 한도 안에서 월 고정비 없이 운영할 수 있다. 단, GCP 무료 한도는 지출 상한이
아니므로 사용량 확인과 예산 알림이 필요하다.

```
[사용자] → Vercel(Next.js PWA) → Cloud Run(Spring API) → Neon PostgreSQL
                                             ↘ Claude API
```

> **e2-micro를 기본안에서 제외한 이유:** VM/디스크 무료 한도와 별도로 외부 IPv4가 과금된다.
> 공개 API를 월 고정비 0원으로 운영하려는 목표에는 Cloud Run의 scale-to-zero가 더 적합하다.

## 1. 확정 구성과 제약

| 구성요소 | 플랜/설정 | 무료 운영의 핵심 제약 |
|---|---|---|
| Web | Vercel Hobby | 개인·비상업 프로젝트 전용, 한도 초과 시 일시 중지 |
| API | Cloud Run, `asia-northeast3` | min 0, max 1; 콜드스타트; 무료량 초과 가능 |
| DB | Neon Free PostgreSQL | 0.5GB, 월 compute 한도, 5분 유휴 후 scale-to-zero |
| Image | Artifact Registry | 저장 이미지/레이어를 0.5GB 안팎으로 관리 |
| Secret | Secret Manager | 활성 secret/version 수와 access 무료 한도 관리 |

Spring의 내부 스케줄러는 인스턴스가 0으로 내려가면 실행이 보장되지 않는다. Cloud Run에서는
`GEN_ENABLED=false`로 배포하고, 필요할 때 admin API를 수동 호출한다. 정기 생성은 추후
GitHub Actions 일일 스케줄로 옮길 수 있다.

## 2. 사전 준비

1. Neon Free 프로젝트를 만들고 가능한 한 한국과 가까운 리전을 선택한다.
2. Neon 대시보드에서 **pooled connection** 문자열을 복사한다.
3. GCP 프로젝트를 만들고 결제 계정을 연결한다. Cloud Run 사용에는 결제 연결이 필요하다.
4. 로컬 gcloud에 로그인한다: `gcloud auth login`.

## 3. API 배포

```bash
cp infra/.env.cloudrun.example infra/.env.cloudrun
# infra/.env.cloudrun에 GCP/Neon/Vercel/Claude 값을 입력
bash infra/deploy-cloudrun.sh
```

스크립트는 필요한 API 활성화, Artifact Registry 생성, 비밀값 저장, Cloud Build, Cloud Run
배포와 헬스체크를 순서대로 수행한다. 비밀값은 이미지나 일반 환경변수에 넣지 않는다.

배포가 끝나면 출력되는 `https://jobstudy-api-....run.app` URL을 기록한다.

## 4. Web 배포

1. Vercel에서 이 저장소를 Import한다.
2. Root Directory를 `apps/web`으로 지정한다.
3. `NEXT_PUBLIC_API_BASE`를 위 Cloud Run URL로 설정한다.
4. 배포 후 실제 Vercel URL을 `infra/.env.cloudrun`의 `CORS_ORIGINS`에 넣고 API를 재배포한다.

## 5. 비용 안전장치

- Cloud Run은 `min=0`, `max=1`, CPU 1, 메모리 1GiB로 제한한다.
- AI 생성은 기본 비활성화하고 면접 턴/일일 토큰 한도를 낮게 시작한다.
- GCP 예산 알림을 설정한다. 일반 예산 알림은 서비스를 자동 중지하지 않는다는 점에 유의한다.
- GCP 콘솔에서 프로젝트에 Cloud Run spend cap을 사용할 수 있으면 추가한다.
- Neon Usage에서 storage와 CU-hours를 주기적으로 확인한다.

세부 결정과 대안 비교는 `docs/adr/0001-free-tier-cloud.md`에 있다.

---

## 레거시 대안: e2-micro VM

아래 내용은 외부 IPv4 비용을 허용할 때만 사용하는 대안이다. **완전 무료 구성은 아니다.**

## ⚠️ 무료 한도를 벗어나는 3가지

과금되는 흔한 실수다. 순서대로 확인할 것.

| 항목 | 무료 조건 | 벗어나면 |
|---|---|---|
| **리전** | `us-west1`, `us-central1`, `us-east1` **만** | 도쿄·서울 등은 전부 유료 |
| **머신 타입** | `e2-micro` 1대 | e2-small 이상은 유료 |
| **부팅 디스크** | `pd-standard` 30GB 이하 | `pd-balanced`(gcloud 기본값!)는 유료 |

egress 는 북미 → 전 세계 월 1GB 까지 무료다. 텍스트 위주라 혼자 쓰기엔 여유롭지만 무제한은 아니다.

미국 리전이라 한국에서 API 왕복이 150ms 안팎 늘어난다. 카드 조회는 체감되고, 면접은 Claude
호출 자체가 수 초라 묻힌다. 프론트는 Vercel 엣지가 서빙하므로 초기 로딩 영향은 작다.

## 1. 사전 준비 (직접)

1. GCP 계정 생성 + **결제 계정 연결** (Always Free 한도 내에서는 청구되지 않지만 카드 등록은 필수)
2. 프로젝트 생성
3. `gcloud` 설치 후 인증

```bash
gcloud auth login
gcloud config set project <PROJECT_ID>
gcloud services enable compute.googleapis.com
```

## 2. VM 생성

```bash
gcloud compute instances create jobstudy \
  --zone=us-west1-b \
  --machine-type=e2-micro \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --boot-disk-type=pd-standard \
  --tags=jobstudy-api
```

`--boot-disk-type=pd-standard` 를 빠뜨리면 `pd-balanced` 로 만들어져 과금된다.

### 방화벽

```bash
gcloud compute firewall-rules create allow-jobstudy-api \
  --allow=tcp:8080,tcp:80,tcp:443 \
  --target-tags=jobstudy-api \
  --description="jobStudy API + HTTPS"
```

공인 IP 확인:

```bash
gcloud compute instances describe jobstudy --zone=us-west1-b \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

## 3. 이미지 빌드 & 푸시 (로컬에서)

**e2-micro 에서 Gradle 빌드를 돌리면 OOM 이 나거나 30분 넘게 걸린다.** 메모리 넉넉한 로컬에서
빌드해 레지스트리에 올리고, VM 은 pull 만 하게 한다. GHCR 은 무료다.

```bash
# Apple Silicon(ARM)에서 x86_64 VM 용 이미지를 만들려면 --platform 이 필수다.
# 빼먹으면 VM 에서 "exec format error" 로 죽는다.
docker buildx build --platform linux/amd64 \
  -t ghcr.io/<github-user>/jobstudy-api:latest \
  --push apps/api
```

GHCR 이 처음이면 `write:packages` 권한 PAT 로 로그인한다.

```bash
echo $GHCR_PAT | docker login ghcr.io -u <github-user> --password-stdin
```

## 4. VM 셋업

```bash
gcloud compute ssh jobstudy --zone=us-west1-b

# VM 안에서
git clone <repo> && cd <repo>/infra
cp .env.example .env && nano .env    # API_IMAGE, DB_PASSWORD, ADMIN_TOKEN, ANTHROPIC_API_KEY
bash setup.sh
```

`setup.sh` 가 하는 일: 스왑 2GB 생성 → Docker 설치 → 이미지 pull → 기동 → 헬스체크.
**스왑이 1단계인 이유는 1GB RAM 으로 Postgres+JVM 을 동시에 못 버티기 때문이다.**

## 5. HTTPS

- Cloudflare 에 도메인 연결 → A 레코드를 VM 공인 IP 로
- VM 에 Nginx 리버스 프록시(`:443 → :8080`) + Let's Encrypt, 또는 Cloudflare Tunnel

## 6. 프론트 — Vercel

1. Vercel → New Project → 이 레포 Import
2. **Root Directory = `apps/web`**
3. 환경변수 `NEXT_PUBLIC_API_BASE = https://api.<your-domain>`
4. Deploy → 배포된 도메인을 VM `.env` 의 `CORS_ORIGINS` 에 반영하고 `docker compose up -d`

## 7. 메모리 예산

1GB 안에 전부 들어가야 해서 배분이 빡빡하다. 한 쪽을 키우면 다른 쪽이 OOM 으로 죽는다.

| 구성요소 | 배정 | 설정 위치 |
|---|---|---|
| OS + Docker 데몬 | ~250MB | — |
| Postgres | 200MB (`mem_limit`) | `docker-compose.yml` |
| API (JVM) | 512MB (`mem_limit`), 힙은 그 중 60% | `docker-compose.yml` → `JAVA_OPTS` |
| 스왑 | 2GB | `setup.sh` |

메모리 문제 진단:

```bash
free -h
docker stats --no-stream
dmesg | grep -i 'out of memory'   # OOM 킬러가 잡았는지
```

## 8. 운영 체크리스트

- [ ] 리전이 `us-west1`/`us-central1`/`us-east1` 인지
- [ ] 부팅 디스크가 `pd-standard` 30GB 인지
- [ ] `ADMIN_TOKEN` 설정 (없으면 admin 엔드포인트 전면 차단 — 안전 기본값)
- [ ] `ANTHROPIC_API_KEY` 설정 (없으면 생성 배치 스킵, 면접은 503)
- [ ] `CORS_ORIGINS` 를 실제 Vercel 도메인으로 좁히기
- [ ] 면접 API 노출 범위 검토 — 공개 상태면 외부 호출이 그대로 Claude 요금이 된다
- [ ] 생성 테스트: `curl -X POST -H "X-Admin-Token: $ADMIN_TOKEN" https://api.../api/v1/admin/generate`
- [ ] PostgreSQL 볼륨 백업 (`pgdata`)
- [ ] GCP 결제 알림 설정 (한도 이탈 조기 발견)

## 9. CI

`.github/workflows/ci.yml` — push 마다 API(`./gradlew build`) + Web(`npm run build`) 검증.

## 10. 비용

| 항목 | 비용 |
|---|---|
| GCP e2-micro + 30GB pd-standard | VM/디스크 무료, 외부 IPv4는 별도 과금 |
| Vercel (취미 플랜) | 0원 |
| Cloudflare DNS | 0원 |
| Claude API | 설정된 카드/면접 일일 토큰 캡으로 통제되는 별도 변동비 |

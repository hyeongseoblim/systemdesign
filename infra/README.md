# 배포 가이드 — Google Cloud Run + Neon + Vercel

```
[모바일 브라우저] → Vercel (Next.js PWA) → Cloud Run (Spring Boot API) → Neon (PostgreSQL)
                                                    ↓
                                            Claude API (카드 생성)
                    ↑
        GitHub Actions 크론 (매일 09:00 KST, 생성 배치 트리거)
```

## 왜 이 조합인가

원래 계획은 Oracle Cloud A1.Flex VM 이었으나 두 가지 이유로 접었다.

1. **가입 자체가 막힘** — Oracle 무료 티어는 검증이 업계에서 가장 빡빡하다.
2. **한도 축소** — Always Free A1 한도가 4 OCPU/24GB → 2 OCPU/12GB 로 줄었고, 2026-08-18 이후 초과 인스턴스는 종료된다. capacity 확보도 여전히 로또다.

GCP 로 옮기면 후보가 둘인데, **결정적인 차이는 외부 IPv4 과금**이다.

| | Cloud Run | GCE e2-micro |
|---|---|---|
| 인스턴스 비용 | 무료 티어 내 0원 | Always Free 0원 |
| **외부 IPv4** | **불필요 (0원)** | **$0.005/h ≈ 월 3.6달러** |
| 리전 | 도쿄 선택 가능 (RTT ~35ms) | **us-west1/central1/east1 강제** (RTT ~130ms) |
| Always-on | ❌ scale-to-zero | ✅ |
| 콜드 스타트 | 있음 (JVM, 대응 필요) | 없음 |
| 운영 부담 | 없음 (관리형) | SSH·swap·Docker·HTTPS 직접 |

GCP Always Free 는 **외부 IP 주소를 포함하지 않는다.** e2-micro 인스턴스 자체는 공짜여도 IP 때문에 월 5,000원가량이 나간다. 외부 IP 없이 쓰려면 아웃바운드용 Cloud NAT 가 필요한데 그건 월 30달러가 넘어 더 나쁘다.

> **면접 포인트** — "서버리스는 트래픽이 몰릴 때 유리하다"는 통념보다, 이 사례처럼 **트래픽이 거의 없을 때 유리하다**는 쪽이 실전에서 더 자주 맞다. 대신 청구서에서 사라진 비용이 **콜드 스타트라는 지연 비용으로 옮겨간 것**뿐이며, 공짜가 아니라 이전(transfer)이라는 점을 짚을 수 있어야 한다.

### 비용

| 항목 | 비용 |
|---|---|
| Cloud Run | 0원 (무료 티어: 월 200만 요청 / 360,000 GiB-초 / 180,000 vCPU-초) |
| Neon PostgreSQL | 0원 (0.5GB — 현재 카드 59개면 수 MB) |
| Vercel Hobby | 0원 |
| GitHub Actions | 0원 (하루 1회 실행) |
| Claude API | 일일 캡(카드 3개 / 20만 토큰)으로 통제되는 변동비 |

> **리전 주의** — Cloud Run 무료 티어의 리전 적용 범위는 자료가 엇갈린다. 공식 가격 페이지는 "Tier 1 리전"이라고 하는데(도쿄 `asia-northeast1` 은 Tier 1), 일부 문서는 미국 3개 리전 한정이라고 쓴다. 이 프로젝트 규모라면 **도쿄가 무료 대상이 아니더라도 월 0.3달러 수준**이라 지연(35ms vs 130ms)을 택할 값어치가 충분하다. 배포 후 아래 **9. 예산 알림**을 반드시 설정하고 며칠 뒤 결제 리포트를 확인할 것. 무조건 0원이어야 한다면 `REGION=us-west1` 로 바꾼다.

---

## 1. Neon PostgreSQL 생성

1. https://neon.tech 가입 (신용카드 불필요)
2. 프로젝트 생성 — **리전은 Cloud Run 과 맞춘다**. 도쿄 배포면 `AWS ap-northeast-1 (Tokyo)`.
3. 데이터베이스 이름 `jobstudy`
4. **Connection Details** 에서 **Pooled connection** 을 선택하고 값을 받아 적는다.

받은 값을 JDBC 형식으로 바꾼다.

```
# Neon 이 주는 형식 (libpq)
postgresql://myuser:mypass@ep-xxx-pooler.ap-northeast-1.aws.neon.tech/jobstudy?sslmode=require

# .env.cloudrun 에 넣을 형식 (JDBC — 계정/비번은 분리)
DB_URL=jdbc:postgresql://ep-xxx-pooler.ap-northeast-1.aws.neon.tech/jobstudy?sslmode=require
DB_USER=myuser
DB_PASSWORD=mypass
```

> **함정 1 — 반드시 pooler 엔드포인트를 쓸 것.** 호스트명에 `-pooler` 가 붙은 쪽이다. Cloud Run 은 인스턴스가 0↔3 사이를 오가며 그때마다 HikariCP 풀이 통째로 새로 생긴다. 직접 연결을 쓰면 Neon 무료 티어의 커넥션 한도를 금방 소진한다. `DB_POOL_MAX=5` 도 같은 이유로 기본값(10)보다 낮춰 뒀다.
>
> **함정 2 — `sslmode=require` 를 빼면 안 된다.** Neon 은 평문 연결을 거부한다.
>
> **함정 3 — auto-suspend.** Neon 무료 티어는 5분 무활동 시 컴퓨트를 재운다. 깨어나는 데 ~300ms 라 실사용에는 문제없지만, 콜드 스타트와 겹치면 첫 요청이 그만큼 더 느려진다.

## 2. gcloud CLI 설치·인증

```bash
# macOS
brew install --cask google-cloud-sdk

gcloud auth login
gcloud projects list          # PROJECT_ID 확인
```

프로젝트가 없으면 만든다. **결제 계정 연결은 필수다** — 무료 티어를 쓰더라도 결제 계정이 없으면 Cloud Run 배포가 거부된다.

```bash
gcloud projects create jobstudy-<임의숫자> --name="jobStudy"
# 콘솔 > 결제 > 이 프로젝트에 결제 계정 연결
```

## 3. 환경 변수 작성

```bash
cd infra
cp .env.cloudrun.example .env.cloudrun
nano .env.cloudrun
```

`ADMIN_TOKEN` 은 반드시 랜덤값으로 생성한다.

```bash
openssl rand -hex 16
```

> `GEN_ENABLED=false` 를 그대로 둔다. Cloud Run 은 유휴 시 인스턴스가 0으로 내려가므로 앱 내부 `@Scheduled` 는 실행되지 않는다. 대신 GitHub Actions 가 admin 엔드포인트를 찌른다(7번). `AdminController.generate()` 는 `props.enabled` 를 검사하지 않으므로 스케줄러를 꺼도 수동/외부 트리거는 정상 동작한다.

## 4. 배포

```bash
cd infra && bash deploy-cloudrun.sh
```

스크립트가 하는 일: API 활성화 → Cloud Build 로 `apps/api` 이미지 빌드 → Cloud Run 배포 → 헬스 체크. 최초 빌드는 5분 내외 걸린다(Gradle + Kotlin 컴파일).

성공하면 `https://jobstudy-api-xxxx.asia-northeast1.run.app` 형태의 URL 이 출력된다. **HTTPS 인증서는 자동으로 붙는다** — Nginx 도 Let's Encrypt 도 Cloudflare 도 필요 없다.

배포 직후 Flyway 가 스키마를 만들고 `ContentSeeder` 가 카드 59개를 적재한다. 확인:

```bash
curl 'https://<URL>/api/v1/cards?limit=3'
```

## 5. Vercel 프론트 배포

1. Vercel → New Project → 이 레포 Import
2. **Root Directory = `apps/web`**
3. 환경변수 `NEXT_PUBLIC_API_BASE` = 4번에서 받은 Cloud Run URL
4. Deploy

## 6. CORS 좁히기

배포 전에는 Vercel 도메인을 모르므로 마지막에 좁힌다. `.env.cloudrun` 의 `CORS_ORIGINS` 를 실제 도메인으로 바꾸고 재배포한다.

```bash
CORS_ORIGINS=https://jobstudy.vercel.app
```
```bash
bash deploy-cloudrun.sh
```

## 7. 데일리 생성 크론 (GitHub Actions)

레포 **Settings → Secrets and variables → Actions → New repository secret** 에서 두 개를 등록한다.

| 이름 | 값 |
|---|---|
| `API_BASE` | Cloud Run URL (끝에 `/` 없이) |
| `ADMIN_TOKEN` | `.env.cloudrun` 과 동일한 값 |

`.github/workflows/generate.yml` 이 매일 00:00 UTC(=09:00 KST)에 실행된다. 즉시 테스트하려면 Actions 탭 → **Daily Card Generation** → **Run workflow**.

> **크론 운영상 함정 두 가지**
> - GitHub 크론은 정시를 보장하지 않는다(부하에 따라 수십 분 지연). 카드 생성 배치라 문제없지만, 분 단위 정확도가 필요하면 Cloud Scheduler 를 쓴다.
> - **레포에 60일간 커밋이 없으면 GitHub 이 스케줄 워크플로를 자동 비활성화한다.** 알림 메일이 오지만 놓치기 쉽다. 어느 날 카드가 안 늘어나 있으면 Actions 탭에서 워크플로가 꺼져 있는지부터 확인할 것.
>
> **면접 포인트** — 스케줄러를 앱 밖으로 뺀 건 서버리스 제약 때문만이 아니다. 인스턴스가 여러 개로 스케일아웃되면 앱 내부 `@Scheduled` 는 **인스턴스 수만큼 중복 실행**된다. 외부 크론 + 단일 HTTP 트리거는 이 문제를 구조적으로 없앤다. 대안은 ShedLock 같은 분산 락인데, 락 유지 비용과 단일 트리거 중 무엇을 택할지가 트레이드오프다.

## 8. 운영 명령어

```bash
# 로그
gcloud run services logs read jobstudy-api --region asia-northeast1 --limit 100

# 실시간 로그
gcloud beta run services logs tail jobstudy-api --region asia-northeast1

# 현재 설정 확인
gcloud run services describe jobstudy-api --region asia-northeast1

# 수동 생성 트리거
curl -X POST -H "X-Admin-Token: $ADMIN_TOKEN" https://<URL>/api/v1/admin/generate

# 품질 게이트에서 보류된 draft 카드 확인
curl -H "X-Admin-Token: $ADMIN_TOKEN" 'https://<URL>/api/v1/admin/drafts?limit=20'
```

## 9. 예산 알림 (필수)

"무료로 쓰려다 청구서 맞는" 사고를 막는 유일한 안전장치다. **배포 직후 바로 설정할 것.**

콘솔 → **결제 → 예산 및 알림 → 예산 만들기**
- 금액: 월 1달러 (이 프로젝트가 정상이면 절대 도달하지 않는다)
- 알림 임계값: 50% / 90% / 100%
- 이메일 수신 체크

`max-instances 3` 도 안전장치다. 트래픽이 튀어도 인스턴스가 무한히 늘지 않는다.

Artifact Registry 무료 한도는 0.5GB 인데 Spring Boot 이미지가 400MB 안팎이라 배포를 반복하면 초과한다. 주기적으로 옛 이미지를 지운다.

```bash
gcloud artifacts docker images list \
  asia-northeast1-docker.pkg.dev/$PROJECT_ID/cloud-run-source-deploy/jobstudy-api

gcloud artifacts docker images delete <IMAGE>@<DIGEST> --delete-tags
```

## 10. 콜드 스타트 — 현재 대응과 다음 단계

Cloud Run 의 유일한 실질적 단점이다. 트래픽이 없으면 인스턴스가 내려가고, 다음 요청에서 JVM 이 처음부터 뜬다.

**현재 적용된 것** (`deploy-cloudrun.sh` 의 `JAVA_OPTS` + 배포 플래그):

| 설정 | 효과 | 대가 |
|---|---|---|
| `--cpu-boost` | 기동 중 CPU 추가 할당 | 없음 (무료) |
| `-XX:TieredStopAtLevel=1` | C2 JIT 생략 → 기동 단축 | 최대 처리량 하락 (사용자 1명이면 무의미) |
| `-XX:+UseSerialGC` | vCPU 1개에서 GC 스레드 오버헤드 제거 | 대용량 힙에서 불리 (해당 없음) |
| `-XX:MaxRAMPercentage=60` | heap ~600MB, non-heap 여유 확보 | 힙 여유 감소 |
| `-Dspring.jmx.enabled=false` | JMX 빈 등록 생략 | JMX 모니터링 불가 |

이걸로 대략 15~20초 → 5~8초 수준이다. 매일 아침 크론이 한 번 깨우므로 그 뒤 15분 안에 여는 첫 접속은 웜 상태다.

**더 줄이려면** — 효과 순:

1. **GraalVM Native Image** — 5~8초 → **~0.1초**, 메모리도 1/5. Spring Boot 3.5 는 AOT 를 정식 지원하지만 Kotlin + JPA/Hibernate 의 리플렉션 힌트 설정이 까다롭고 빌드가 5~10분 걸린다. 투자 대비 효과는 가장 크고, 이직 준비용 프로젝트의 소재로도 최상급이다.
2. **JDK 25 AOT 캐시** (Project Leyden) — 클래스 로딩·링킹 결과를 미리 캐시해 30~40% 단축. 다만 학습 실행(training run)에 실제 DB 가 필요해서 빌드 파이프라인이 복잡해진다.
3. **`--min-instances 1`** — 콜드 스타트가 사라지지만 인스턴스가 상시 떠 있어 **무료 티어를 넘긴다.** 이 프로젝트의 목적(0원)과 정면으로 충돌하므로 쓰지 않는다.

## 11. 대안 — GCE e2-micro (always-on 이 꼭 필요할 때)

콜드 스타트를 도저히 못 견디겠고 월 5,000원을 낼 의향이 있다면.

- 리전은 `us-west1` / `us-central1` / `us-east1` **중에서만** 무료다. 한국에서 RTT ~130ms.
- 머신 타입 `e2-micro` (1 vCPU / 1GB), 부팅 디스크 30GB 표준 영구 디스크까지 무료.
- **DB 는 이 VM 에 올리지 말고 Neon 을 그대로 쓴다.** 1GB 에 JVM 과 PostgreSQL 을 같이 얹으면 빠듯하다.
- **VM 위에서 이미지를 빌드하지 말 것.** Gradle + Kotlin 컴파일은 1GB 에서 OOM 난다. CI 나 로컬에서 빌드해 레지스트리로 올리고 VM 은 pull 만 한다.
- `docker-compose.yml` 의 `JAVA_OPTS` 를 `-Xmx512m -XX:+UseSerialGC` 로 조이고 swap 2GB 를 잡는다.
- HTTPS 는 직접 붙여야 한다(Nginx + Let's Encrypt, 또는 Cloudflare 프록시).

## 12. 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| 배포 시 `PERMISSION_DENIED` | 프로젝트에 결제 계정이 연결되지 않음. 콘솔 → 결제에서 연결. |
| 헬스 체크 실패, 로그에 `Connection refused` | `DB_URL` 오타 또는 `sslmode=require` 누락. |
| 로그에 `too many connections` | pooler 엔드포인트 미사용. 호스트명에 `-pooler` 확인, `DB_POOL_MAX` 축소. |
| 브라우저 콘솔에 CORS 에러 | `CORS_ORIGINS` 가 실제 Vercel 도메인과 불일치. 프로토콜(`https://`) 포함, 끝 슬래시 없이. |
| admin 호출이 401 | `ADMIN_TOKEN` 불일치. 미설정 시 admin 엔드포인트는 전면 차단(안전 기본값)된다. |
| 첫 요청만 매우 느림 | 정상 동작(콜드 스타트). 10번 참고. |
| Cloud Build 가 느리거나 실패 | `apps/api/.gcloudignore` 확인 — `build/`, `.gradle/` 이 업로드되면 수백 MB가 된다. |

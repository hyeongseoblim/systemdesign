# 배포 (Phase 4) — Oracle Free Tier + Vercel

전부 0원. 백엔드는 Oracle A1.Flex VM, 프론트는 Vercel.

```
[사용자] → Vercel(Next.js PWA) → Cloudflare → Oracle VM(API+Postgres) → Claude API
```

## 1. 백엔드 — Oracle A1.Flex VM

### 1-1. VM 준비
- Oracle Cloud → Compute → Instance 생성 (Ampere A1.Flex, Ubuntu 22.04, 1~2 OCPU/6~12GB면 충분)
- 방화벽: 8080(임시), 80/443(Nginx) 인바운드 허용
- Docker 설치: `curl -fsSL https://get.docker.com | sh`

### 1-2. 코드 받고 실행
```bash
git clone <repo> && cd <repo>/infra
cat > .env <<'EOF'
DB_PASSWORD=<강한_비밀번호>
ADMIN_TOKEN=<랜덤_32자>
ANTHROPIC_API_KEY=sk-ant-...
CORS_ORIGINS=https://<your-vercel-app>.vercel.app
GEN_ENABLED=true
EOF
docker compose --env-file .env up -d --build
curl http://localhost:8080/api/v1/health   # {"status":"UP"}
```

### 1-3. HTTPS (필수 — Caddy 내장)

> ⚠️ **Vercel 프론트는 HTTPS라서 API가 `http://IP:8080`이면 브라우저가 Mixed Content로 전부 차단한다.**
> 프론트를 붙이기 전에 반드시 HTTPS를 켜야 한다.

도메인이 없어도 된다 — `sslip.io`(공짜 와일드카드 DNS)로 IP를 도메인처럼 쓸 수 있다:

```bash
# .env 에 추가 (VM 공인 IP가 140.83.1.2 라면)
DOMAIN=api.140.83.1.2.sslip.io

# Security List에 80/443 인바운드 열기 (콘솔) + Ubuntu 방화벽
sudo iptables -I INPUT 6 -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save

# Caddy 포함 재기동 (인증서 자동 발급)
docker compose --profile https --env-file .env up -d
curl https://api.140.83.1.2.sslip.io/api/v1/health   # {"status":"UP"}
```

- 실제 도메인이 있으면 `DOMAIN=api.mydomain.com` + A 레코드만 잡으면 동일하게 동작.
- HTTPS 확인 후에는 Security List의 **8080 인바운드 규칙을 삭제**해 직접 노출을 막는다 (Caddy만 공개).

## 2. 프론트 — Vercel
1. Vercel → New Project → 이 레포 Import
2. **Root Directory = `apps/web`**
3. 환경변수 `NEXT_PUBLIC_API_BASE = https://<DOMAIN>` (위에서 정한 도메인)
4. Deploy
5. 배포된 Vercel 주소를 VM `.env`의 `CORS_ORIGINS`에 반영 후 `docker compose --profile https --env-file .env up -d` 재기동

## 3. CI
`.github/workflows/ci.yml` — push마다 API(`./gradlew build`) + Web(`npm run build`) 검증.

## 4. 운영 체크리스트
- [ ] `ADMIN_TOKEN` 설정 (없으면 admin 엔드포인트 전면 차단됨 — 안전 기본값)
- [ ] `ANTHROPIC_API_KEY` 설정 (없으면 생성 배치 자동 스킵)
- [ ] `CORS_ORIGINS`를 실제 Vercel 도메인으로 좁히기
- [ ] 생성 테스트: `curl -X POST -H "X-Admin-Token: $ADMIN_TOKEN" https://api.../api/v1/admin/generate`
- [ ] PostgreSQL 볼륨 백업 (`pgdata`)

## 5. 비용
| 항목 | 비용 |
|---|---|
| Oracle A1.Flex VM + Postgres | 0원 (Always Free) |
| Vercel (취미 플랜) | 0원 |
| Cloudflare DNS | 0원 |
| Claude API | 일일 캡으로 통제되는 변동비만 |

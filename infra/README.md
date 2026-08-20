# 배포 — Cloud Run + Neon + Vercel

현재 배포 구성은 다음과 같다.

```
[사용자] → Vercel(Next.js PWA) → Cloud Run(Spring/Kotlin API) → Neon(PostgreSQL)
```

- **API**: Cloud Run, Seoul(`asia-northeast3`), 1 vCPU / 1GiB, 최소 인스턴스 0
- **DB**: Neon PostgreSQL. JDBC URL에 `sslmode=require` 사용
- **Web**: Vercel, Root Directory `apps/web`

전체 절차는 [cloudrun/README.md](cloudrun/README.md)를 따른다. 배포 스크립트는 [cloudrun/deploy.sh](cloudrun/deploy.sh)다.

## 로컬 Docker Compose

`docker-compose.yml`은 운영 DB가 아니라 로컬에서 API와 PostgreSQL을 함께 확인할 때만 쓴다.

```bash
cp .env.example .env
docker compose --env-file .env up -d --build
curl http://localhost:8080/api/v1/health
```

## 운영 체크리스트

- [ ] GCP 예산 알림 설정
- [ ] Secret Manager에 DB URL/user/password, admin token 저장
- [ ] `CORS_ORIGINS`를 실제 Vercel 도메인으로 제한
- [ ] Vercel의 `NEXT_PUBLIC_API_BASE`에 Cloud Run URL 설정
- [ ] `/api/v1/health`, 카드 피드, 관리자 인증 실패/성공 확인
- [ ] Neon DB를 정기적으로 `pg_dump` 백업
- [ ] AI 생성은 Cloud Scheduler를 붙인 뒤에만 활성화

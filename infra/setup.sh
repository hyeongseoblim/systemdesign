#!/usr/bin/env bash
# Oracle VM(Ubuntu)에서 jobStudy 백엔드+DB를 한 번에 띄우는 셋업 스크립트.
# 사용: cd ~/SystemDesign/infra && bash setup.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> 1/4 Docker 확인"
if ! command -v docker >/dev/null 2>&1; then
  echo "    Docker 설치 중..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
  echo "    Docker 설치 완료. (그룹 반영 위해 재로그인이 필요할 수 있음)"
fi

echo "==> 2/4 .env 확인"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "    .env 를 생성했습니다. 값을 채운 뒤 다시 실행하세요:"
  echo "       nano $(pwd)/.env"
  exit 1
fi

echo "==> 3/4 빌드 & 기동 (최초 빌드는 수 분 소요)"
docker compose --env-file .env up -d --build

echo "==> 4/4 헬스 체크"
ok=""
for i in $(seq 1 40); do
  if curl -sf http://localhost:8080/api/v1/health >/dev/null 2>&1; then
    ok="yes"; break
  fi
  sleep 3
done

if [ -n "$ok" ]; then
  echo "✅ API 정상 기동: http://localhost:8080/api/v1/health"
  echo "   카드 생성 테스트:"
  echo "     curl -X POST -H \"X-Admin-Token: \$(grep ADMIN_TOKEN .env | cut -d= -f2)\" http://localhost:8080/api/v1/admin/generate"
else
  echo "⚠️ 헬스 체크 실패. 로그 확인:"
  echo "     docker compose logs api --tail=80"
fi

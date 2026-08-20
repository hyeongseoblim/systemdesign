#!/usr/bin/env bash
# GCP e2-micro(Ubuntu, 1GB RAM)에서 jobStudy 백엔드+DB를 한 번에 띄우는 셋업 스크립트.
# 사용: cd ~/jobStudy/infra && bash setup.sh
#
# 1GB VM 이라 스왑 없이는 Postgres+JVM 이 동시에 못 버틴다. 스왑 생성이 1단계인 이유.
set -euo pipefail
cd "$(dirname "$0")"

SWAP_FILE=/swapfile
SWAP_SIZE=2G

echo "==> 1/5 아키텍처 확인"
ARCH=$(uname -m)
echo "    $ARCH"
if [ "$ARCH" != "x86_64" ]; then
  echo "    ⚠️ x86_64 가 아닙니다. 이미지를 이 아키텍처로 빌드했는지 확인하세요."
fi

echo "==> 2/5 스왑 확인 (${SWAP_SIZE})"
if swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
  echo "    이미 활성화됨"
else
  echo "    스왑 생성 중..."
  sudo fallocate -l "$SWAP_SIZE" "$SWAP_FILE" || sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=2048
  sudo chmod 600 "$SWAP_FILE"
  sudo mkswap "$SWAP_FILE" >/dev/null
  sudo swapon "$SWAP_FILE"
  # 재부팅 후에도 유지
  grep -q "$SWAP_FILE" /etc/fstab || echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
  # 1GB RAM 에서는 스왑을 적극적으로 쓰는 편이 OOM 킬러보다 낫다
  sudo sysctl -w vm.swappiness=60 >/dev/null
  echo "    스왑 활성화 완료"
fi
free -h | sed 's/^/    /'

echo "==> 3/5 Docker 확인"
if ! command -v docker >/dev/null 2>&1; then
  echo "    Docker 설치 중..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
  echo "    Docker 설치 완료. (그룹 반영 위해 재로그인이 필요할 수 있음)"
fi

echo "==> 4/5 .env 확인"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "    .env 를 생성했습니다. 값을 채운 뒤 다시 실행하세요:"
  echo "       nano $(pwd)/.env"
  exit 1
fi

echo "==> 5/5 기동"
# API_IMAGE 가 있으면 레지스트리에서 pull, 없으면 이 자리에서 빌드(느리고 OOM 위험).
if grep -q '^API_IMAGE=.\+' .env 2>/dev/null; then
  echo "    레지스트리 이미지 사용 — pull"
  docker compose --env-file .env pull
  docker compose --env-file .env up -d
else
  echo "    ⚠️ API_IMAGE 미지정 — VM 에서 직접 빌드합니다."
  echo "       e2-micro 에서는 수십 분 걸리거나 OOM 으로 실패할 수 있습니다."
  echo "       로컬에서 빌드해 레지스트리에 올리는 방식을 권장합니다 (README 참고)."
  docker compose --env-file .env up -d --build
fi

echo "==> 헬스 체크"
ok=""
for i in $(seq 1 60); do
  if curl -sf http://localhost:8080/api/v1/health >/dev/null 2>&1; then
    ok="yes"; break
  fi
  sleep 3
done

if [ -n "$ok" ]; then
  echo "✅ API 정상 기동: http://localhost:8080/api/v1/health"
  free -h | sed 's/^/    /'
  echo "   카드 생성 테스트:"
  echo "     curl -X POST -H \"X-Admin-Token: \$(grep ADMIN_TOKEN .env | cut -d= -f2)\" http://localhost:8080/api/v1/admin/generate"
else
  echo "⚠️ 헬스 체크 실패. 메모리 부족일 가능성이 높습니다:"
  echo "     docker compose logs api --tail=80"
  echo "     dmesg | grep -i 'out of memory'   # OOM 킬러가 잡았는지 확인"
fi

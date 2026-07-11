#!/usr/bin/env bash
# 로컬 개발 스택 원샷 스크립트.
#
#   scripts/local-dev.sh up      # Postgres(도커) + API(bootRun) + 웹(next dev) 기동
#   scripts/local-dev.sh down    # 전부 종료 (DB 데이터는 볼륨에 유지)
#   scripts/local-dev.sh status  # 상태 확인
#   scripts/local-dev.sh db      # Postgres만 기동 (API/웹은 직접 띄울 때)
#
# 요구사항: Docker, JDK 25, Node 18.18+ (권장 20+)
# 로그: .local/api.log, .local/web.log

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT/infra/docker-compose.local.yml"
RUN_DIR="$ROOT/.local"
API_PORT="${PORT:-8080}"
WEB_PORT="${WEB_PORT:-3000}"

mkdir -p "$RUN_DIR"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
info()  { printf '\033[36m▸ %s\033[0m\n' "$*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { red "'$1' 이(가) 필요합니다 — $2"; exit 1; }
}

check_prereqs() {
  require docker "https://docs.docker.com/get-docker/"
  require java   "JDK 25 설치 (sdkman: sdk install java 25-tem / brew install --cask temurin@25)"
  require node   "Node 20+ 설치 (https://nodejs.org)"
  local jv
  jv=$(java -version 2>&1 | grep -oE 'version "([0-9]+)' | grep -oE '[0-9]+' | head -1)
  if [ "${jv:-0}" -lt 25 ]; then red "JDK 25 이상 필요 (현재: ${jv:-unknown})"; exit 1; fi
}

db_up() {
  info "PostgreSQL 기동 (docker compose)"
  docker compose -f "$COMPOSE_FILE" up -d
  info "PostgreSQL healthy 대기..."
  local i=0
  until docker inspect --format '{{.State.Health.Status}}' jobstudy-pg-local 2>/dev/null | grep -q healthy; do
    i=$((i+1)); [ "$i" -gt 30 ] && { red "PostgreSQL 이 30초 내에 healthy 가 되지 않았습니다"; exit 1; }
    sleep 1
  done
  green "PostgreSQL ready (localhost:5432, db/user/pw = jobstudy)"
}

api_up() {
  if curl -sf "http://localhost:$API_PORT/api/v1/health" >/dev/null 2>&1; then
    green "API 이미 실행 중 (:$API_PORT)"; return
  fi
  info "API 기동 (gradlew bootRun) — 로그: .local/api.log"
  ( cd "$ROOT/apps/api" && nohup ./gradlew bootRun --console=plain >"$RUN_DIR/api.log" 2>&1 & echo $! >"$RUN_DIR/api.pid" )
  info "API health 대기 (첫 실행이면 의존성 다운로드로 수 분 걸릴 수 있음)..."
  local i=0
  until curl -sf "http://localhost:$API_PORT/api/v1/health" >/dev/null 2>&1; do
    i=$((i+1)); [ "$i" -gt 300 ] && { red "API 가 기동되지 않았습니다 — .local/api.log 확인"; exit 1; }
    sleep 2
  done
  green "API ready (http://localhost:$API_PORT)"
}

web_up() {
  if curl -sf "http://localhost:$WEB_PORT" >/dev/null 2>&1; then
    green "웹 이미 실행 중 (:$WEB_PORT)"; return
  fi
  cd "$ROOT/apps/web"
  [ -f .env.local ] || cp .env.example .env.local
  [ -d node_modules ] || { info "npm ci (최초 1회)"; npm ci; }
  info "웹 기동 (next dev) — 로그: .local/web.log"
  ( nohup npm run dev -- --port "$WEB_PORT" >"$RUN_DIR/web.log" 2>&1 & echo $! >"$RUN_DIR/web.pid" )
  local i=0
  until curl -sf "http://localhost:$WEB_PORT" >/dev/null 2>&1; do
    i=$((i+1)); [ "$i" -gt 60 ] && { red "웹이 기동되지 않았습니다 — .local/web.log 확인"; exit 1; }
    sleep 1
  done
  green "웹 ready (http://localhost:$WEB_PORT)"
}

kill_pidfile() {
  local f="$RUN_DIR/$1.pid"
  if [ -f "$f" ]; then
    local pid; pid=$(cat "$f")
    # bootRun/next 는 자식 프로세스를 만들므로 프로세스 그룹째 종료
    kill -- -"$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')" 2>/dev/null || kill "$pid" 2>/dev/null || true
    rm -f "$f"
  fi
}

case "${1:-up}" in
  up)
    check_prereqs
    db_up
    api_up
    web_up
    echo
    green "로컬 스택 준비 완료"
    echo "  피드:   http://localhost:$WEB_PORT"
    echo "  API:    http://localhost:$API_PORT/api/v1/health"
    echo "  종료:   scripts/local-dev.sh down"
    ;;
  db)
    check_prereqs
    db_up
    ;;
  down)
    info "API/웹 종료"
    kill_pidfile api
    kill_pidfile web
    pkill -f "org.springframework.boot.*jobstudy" 2>/dev/null || true
    info "PostgreSQL 종료 (데이터 볼륨 유지 — 완전 삭제는 docker compose -f infra/docker-compose.local.yml down -v)"
    docker compose -f "$COMPOSE_FILE" down
    green "종료 완료"
    ;;
  status)
    docker compose -f "$COMPOSE_FILE" ps || true
    curl -sf "http://localhost:$API_PORT/api/v1/health" >/dev/null 2>&1 \
      && green "API: UP (:$API_PORT)" || red "API: DOWN"
    curl -sf "http://localhost:$WEB_PORT" >/dev/null 2>&1 \
      && green "웹: UP (:$WEB_PORT)" || red "웹: DOWN"
    ;;
  *)
    echo "사용법: scripts/local-dev.sh [up|db|down|status]"; exit 1 ;;
esac

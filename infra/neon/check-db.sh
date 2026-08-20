#!/usr/bin/env bash
# Neon PostgreSQL 읽기 전용 상태 점검. 스키마나 데이터를 변경하지 않는다.
set -euo pipefail

for required_var in DB_URL DB_USER DB_PASSWORD; do
  if [ -z "${!required_var:-}" ]; then
    echo "$required_var is required." >&2
    exit 1
  fi
done

command -v psql >/dev/null 2>&1 || {
  echo "psql is required. Install PostgreSQL client tools first." >&2
  exit 1
}

case "$DB_URL" in
  jdbc:postgresql://*) JOBSTUDY_PSQL_URL="postgresql://${DB_URL#jdbc:postgresql://}" ;;
  postgresql://*) JOBSTUDY_PSQL_URL="$DB_URL" ;;
  *)
    echo "DB_URL must start with jdbc:postgresql:// or postgresql://" >&2
    exit 1
    ;;
esac

export PGPASSWORD="$DB_PASSWORD"

PSQL=(
  psql "$JOBSTUDY_PSQL_URL"
  --username "$DB_USER"
  --no-psqlrc
  --set ON_ERROR_STOP=1
  --pset pager=off
)

echo "[1/4] Connection"
"${PSQL[@]}" --command \
  "SELECT current_database() AS database, current_user AS role, current_setting('server_version') AS server_version;"

FLYWAY_TABLE="$("${PSQL[@]}" --tuples-only --no-align --command \
  "SELECT coalesce(to_regclass('public.flyway_schema_history')::text, '');")"
if [ "$FLYWAY_TABLE" != "flyway_schema_history" ]; then
  echo "flyway_schema_history is missing. Deploy the API once so Flyway can initialize the database." >&2
  exit 2
fi

echo "[2/4] Flyway migrations"
"${PSQL[@]}" --command \
  "SELECT installed_rank, version, description, success, installed_on FROM flyway_schema_history ORDER BY installed_rank;"

echo "[3/4] Card inventory"
"${PSQL[@]}" --command \
  "SELECT source, status, count(*) AS cards FROM cards GROUP BY source, status ORDER BY source, status;"

echo "[4/4] Curriculum resolution"
"${PSQL[@]}" --command \
  "SELECT resolution_status, count(*) AS topics FROM curriculum_topics GROUP BY resolution_status ORDER BY resolution_status;"

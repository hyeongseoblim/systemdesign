#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOBSTUDY_GRADLE_HOME="${GRADLE_USER_HOME:-$PROJECT_ROOT/.local/gradle}"

GRADLE_USER_HOME="$JOBSTUDY_GRADLE_HOME" \
  "$PROJECT_ROOT/apps/api/gradlew" \
  -p "$PROJECT_ROOT/apps/api" \
  test --tests com.jobstudy.content.ContentContractTest \
  --no-daemon --console=plain

printf 'Content contract passed.\n'

#!/usr/bin/env bash
# detect-dbt.sh — Detects which dbt CLI is available and its capabilities
# Usage: source scripts/detect-dbt.sh
#        Then use $DBT_CMD to run commands
set -euo pipefail

DBT_CMD=""
DBT_ENGINE=""
DBT_VERSION=""
DBT_HAS_SL_CLI=false
DBT_HAS_INLINE_COMPUTE=false
DBT_HAS_PULL=false

# Priority: dbt-fusion (dbtf alias or dbt-fusion binary) > dbt Cloud CLI > dbt-core
if command -v dbtf &>/dev/null; then
  DBT_CMD="dbtf"
  DBT_ENGINE="fusion"
  DBT_VERSION=$(dbtf --version 2>&1 | head -1)
elif command -v dbt-fusion &>/dev/null; then
  DBT_CMD="dbt-fusion"
  DBT_ENGINE="fusion"
  DBT_VERSION=$(dbt-fusion --version 2>&1 | head -1)
elif command -v dbt &>/dev/null; then
  DBT_CMD="dbt"
  VERSION_OUTPUT=$(dbt --version 2>&1 | head -1)
  if echo "$VERSION_OUTPUT" | grep -qi "cloud"; then
    DBT_ENGINE="cloud-cli"
  else
    DBT_ENGINE="core"
  fi
  DBT_VERSION="$VERSION_OUTPUT"
else
  echo "ERROR: No dbt CLI found. Install one of:"
  echo "  - dbt Fusion: https://docs.getdbt.com/docs/dbt-fusion"
  echo "  - dbt Cloud CLI: https://docs.getdbt.com/docs/cloud/cloud-cli-installation"
  echo "  - dbt Core: pip install dbt-core dbt-{adapter}"
  exit 1
fi

# Detect Fusion-specific capabilities
if [ "$DBT_ENGINE" = "fusion" ]; then
  DBT_HAS_SL_CLI=true         # dbt sl list/query/validate
  DBT_HAS_INLINE_COMPUTE=true # --compute inline (no warehouse needed)
  DBT_HAS_PULL=true           # dbt pull (download data from warehouse)
fi

echo "Detected: $DBT_VERSION"
echo "  Engine:         $DBT_ENGINE"
echo "  Command:        $DBT_CMD"
echo "  SL CLI:         $DBT_HAS_SL_CLI"
echo "  Inline compute: $DBT_HAS_INLINE_COMPUTE"
echo "  Pull command:   $DBT_HAS_PULL"

export DBT_CMD DBT_ENGINE DBT_VERSION DBT_HAS_SL_CLI DBT_HAS_INLINE_COMPUTE DBT_HAS_PULL

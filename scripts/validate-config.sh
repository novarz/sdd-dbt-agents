#!/usr/bin/env bash
# validate-config.sh — Validates project-config.yaml before Phase 6 or terraform apply
# Usage: ./scripts/validate-config.sh [path/to/project-config.yaml]
set -euo pipefail

CONFIG="${1:-project-config.yaml}"

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: $CONFIG not found."
  echo "Run: cp project-config.example.yaml project-config.yaml"
  exit 1
fi

ERRORS=()
WARNINGS=()

# ─── Helper: read a YAML value (simple key: value parsing, no nested support) ─
yaml_val() {
  local raw
  raw=$(grep -E "^\s*$1:" "$CONFIG" | head -1 | sed "s/.*$1://" || true)
  # Strip leading/trailing whitespace, inline comments, and quotes
  echo "$raw" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/[[:space:]]*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
}

# ─── Helper: check for placeholder values ────────────────────────────────────
check_placeholder() {
  local key="$1"
  local val="$2"
  local label="${3:-$key}"

  if [ -z "$val" ]; then
    ERRORS+=("$label: empty or missing")
  elif echo "$val" | grep -qiE '(^(000)|MY_|REPLACE|TODO|TBD)'; then
    ERRORS+=("$label: still has placeholder value '$val'")
  fi
}

echo "Validating $CONFIG..."
echo ""

# ─── Warehouse platform ──────────────────────────────────────────────────────
PLATFORM=$(yaml_val "warehouse_platform")
if [ -z "$PLATFORM" ]; then
  ERRORS+=("warehouse_platform: missing")
elif [[ ! "$PLATFORM" =~ ^(snowflake|bigquery|databricks)$ ]]; then
  ERRORS+=("warehouse_platform: invalid value '$PLATFORM' (must be snowflake, bigquery, or databricks)")
fi

# ─── dbt Platform ────────────────────────────────────────────────────────────
check_placeholder "account_id" "$(yaml_val 'account_id')" "dbt_platform.account_id"
check_placeholder "host_url" "$(yaml_val 'host_url')" "dbt_platform.host_url"
check_placeholder "project_name" "$(yaml_val 'project_name')" "dbt_platform.project_name"

HOST_URL=$(yaml_val "host_url")
if [ -n "$HOST_URL" ] && ! echo "$HOST_URL" | grep -q '/api$'; then
  WARNINGS+=("dbt_platform.host_url: should end with /api (e.g. https://emea.dbt.com/api)")
fi

# ─── Git ──────────────────────────────────────────────────────────────────────
check_placeholder "remote_url" "$(yaml_val 'remote_url')" "git.remote_url"
check_placeholder "github_installation_id" "$(yaml_val 'github_installation_id')" "git.github_installation_id"

# ─── Warehouse-specific checks ───────────────────────────────────────────────
case "$PLATFORM" in
  snowflake)
    check_placeholder "account" "$(yaml_val 'account')" "snowflake.account"
    check_placeholder "database" "$(yaml_val 'database')" "snowflake.database"
    check_placeholder "warehouse" "$(yaml_val 'warehouse')" "snowflake.warehouse"
    check_placeholder "user" "$(yaml_val 'user')" "snowflake.user"
    ;;
  bigquery)
    check_placeholder "gcp_project_id" "$(yaml_val 'gcp_project_id')" "bigquery.gcp_project_id"
    check_placeholder "client_email" "$(yaml_val 'client_email')" "bigquery.client_email"
    check_placeholder "client_id" "$(yaml_val 'client_id')" "bigquery.client_id"
    ;;
  databricks)
    check_placeholder "host" "$(yaml_val 'host')" "databricks.host"
    check_placeholder "http_path" "$(yaml_val 'http_path')" "databricks.http_path"
    check_placeholder "catalog" "$(yaml_val 'catalog')" "databricks.catalog"
    ;;
esac

# ─── Schemas ─────────────────────────────────────────────────────────────────
check_placeholder "prefix" "$(yaml_val 'prefix')" "schemas.prefix"

# ─── Sources ─────────────────────────────────────────────────────────────────
SOURCE_DB=$(yaml_val "source_database")
SOURCE_PREFIX=$(yaml_val "source_schema_prefix")
if [ -z "$SOURCE_DB" ]; then
  WARNINGS+=("sources.source_database: not set — agents will need to ask for it")
fi
if [ -z "$SOURCE_PREFIX" ]; then
  WARNINGS+=("sources.source_schema_prefix: not set — agents will need to ask for it")
fi

# ─── .env check ──────────────────────────────────────────────────────────────
if [ ! -f .env ]; then
  WARNINGS+=(".env file not found — sensitive credentials won't be available. Run: cp .env.example .env")
fi

# ─── Report ───────────────────────────────────────────────────────────────────
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "Warnings:"
  for w in "${WARNINGS[@]}"; do
    echo "  ⚠  $w"
  done
  echo ""
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "Errors (must fix before proceeding):"
  for e in "${ERRORS[@]}"; do
    echo "  ✗  $e"
  done
  echo ""
  echo "FAILED: $CONFIG has ${#ERRORS[@]} error(s). Fix them and re-run."
  exit 1
else
  echo "OK: $CONFIG is valid for warehouse_platform=$PLATFORM"
  exit 0
fi

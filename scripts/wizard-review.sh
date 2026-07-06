#!/usr/bin/env bash
# wizard-review.sh — Phase 5 warehouse-aware review via dbt Wizard (headless).
#
# Produces Wizard's code/warehouse findings for a feature's changes. This does NOT
# replace the dbt-reviewer subagent: the orchestrator still runs dbt-reviewer to add
# the requirement->code traceability and acceptance-criteria coverage that Wizard
# cannot know (it doesn't read the specs). `wizard review` has NO --json, so output is
# captured as text for the orchestrator to fold into review.md.
#
# Usage:
#   scripts/wizard-review.sh <feature> [base-branch]
# Env:
#   BASE   base branch to diff against.   default: arg 2, else "main"
set -euo pipefail

FEATURE="${1:?feature slug required}"
BASE="${2:-${BASE:-main}}"

OUTDIR="specs/.wizard"
OUT="${OUTDIR}/${FEATURE}.review.txt"
mkdir -p "$OUTDIR"

if ! command -v wizard &>/dev/null; then
  echo "ERROR: 'wizard' CLI not found. Install dbt Wizard or set execution_backend=claude-code." >&2
  exit 127
fi
# Provider-agnostic BYOK check (see wizard-exec.sh): any supported provider env var OR
# stored creds from `wizard providers configure`.
_wizard_auth_ok() {
  [ -f "${HOME}/.dbt/wizard/provider-auth.json" ] && return 0
  for v in ANTHROPIC_API_KEY OPENAI_API_KEY AZURE_OPENAI_API_KEY GEMINI_API_KEY \
           GOOGLE_API_KEY AWS_ACCESS_KEY_ID AWS_PROFILE SNOWFLAKE_ACCOUNT; do
    [ -n "${!v:-}" ] && return 0
  done
  return 1
}
if ! _wizard_auth_ok; then
  echo "ERROR: no dbt Wizard BYOK credentials found. Run 'wizard providers configure <provider>'" >&2
  echo "       or export a provider env var. See .env.example. Or set execution_backend=claude-code." >&2
  exit 3
fi

# Review committed changes on this branch vs base if the base exists; otherwise fall
# back to reviewing uncommitted working-tree changes.
set +e
if git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo ">> wizard review --base ${BASE} (feature=${FEATURE})"
  wizard review --base "$BASE" --title "SDD ${FEATURE}" > "$OUT" 2>&1
  RC=$?
else
  echo ">> base '${BASE}' not found; reviewing uncommitted changes"
  wizard review --uncommitted --title "SDD ${FEATURE}" > "$OUT" 2>&1
  RC=$?
fi
set -e

if [ $RC -ne 0 ]; then
  echo "WIZARD_REVIEW_FAILED feature=${FEATURE} rc=${RC} out=${OUT}" >&2
  exit $RC
fi

echo "WIZARD_REVIEW_OK feature=${FEATURE} findings=${OUT}"
echo ">> orchestrator: launch dbt-reviewer, feed it ${OUT} + the specs, produce review.md"

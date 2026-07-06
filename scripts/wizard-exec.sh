#!/usr/bin/env bash
# wizard-exec.sh — Delegate ONE atomic SDD Phase 4 task to dbt Wizard (headless).
#
# This is the orchestrator's execution node when execution_backend=wizard. It runs a
# single, already-approved task; it NEVER commits (the orchestrator commits with the
# traceable [SDD-{feature}] T-{ID} message). It captures a diff for the human gate and
# returns Wizard's exit code so the orchestrator can apply the Smart Retry Protocol.
#
# Usage:
#   scripts/wizard-exec.sh <agent-name> <task-id> "<task prompt>"
# Env:
#   FEATURE      feature slug (for output paths / logs).           default: adhoc
#   HEADLESS     "true" only inside an externally sandboxed CI.    default: false
#   DBT_CMD      dbt command (from detect-dbt.sh).                 default: dbt
#   WIZARD_MODEL override model (else Wizard/config.toml default). default: unset
#
# Outputs (under specs/.wizard/, git-ignored):
#   <task>.events.jsonl  full JSONL event stream (errors live here for retry)
#   <task>.last.txt      agent's final message
#   <task>.diff          git diff of the changes (for the gate)
set -euo pipefail

AGENT="${1:?agent name required}"
TASK="${2:?task id required}"
PROMPT="${3:?task prompt required}"

FEATURE="${FEATURE:-adhoc}"
HEADLESS="${HEADLESS:-false}"
DBT_CMD="${DBT_CMD:-dbt}"

OUTDIR="specs/.wizard"
EVENTS="${OUTDIR}/${TASK}.events.jsonl"
LAST="${OUTDIR}/${TASK}.last.txt"
DIFF="${OUTDIR}/${TASK}.diff"
mkdir -p "$OUTDIR"

# ── Preflight ────────────────────────────────────────────────────────────────
if ! command -v wizard &>/dev/null; then
  echo "ERROR: 'wizard' CLI not found. Install dbt Wizard or set execution_backend=claude-code." >&2
  exit 127
fi
# BYOK is mandatory for the CLI (no dbt platform managed model on this path), but the
# provider is your choice: Anthropic, OpenAI, Azure, Bedrock, Gemini, or Snowflake Cortex.
# Provider-agnostic check: accept EITHER a supported provider env var OR stored creds
# from `wizard providers configure` (~/.dbt/wizard/provider-auth.json). Documented gap,
# never a real credential in this repo.
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
  echo "       (e.g. snowflake, anthropic, bedrock, azure, gemini, openai) or export a provider" >&2
  echo "       env var. See .env.example. Alternatively set execution_backend=claude-code." >&2
  exit 3
fi

# Metadata engine reads target/manifest.json — refresh project state before delegating.
echo ">> dbt parse (refresh target/ for Wizard metadata engine)"
if ! $DBT_CMD parse; then
  echo "ERROR: '$DBT_CMD parse' failed — fix the project before delegating to Wizard." >&2
  exit 4
fi

# ── Approval / sandbox policy ────────────────────────────────────────────────
# Interactive: sandboxed workspace-write, ask on request. The HUMAN approval happens
# later at the orchestrator gate (with the diff), NOT inside exec.
# Headless: only inside an externally sandboxed runner — bypass prompts entirely.
APPROVAL_FLAGS=(-a on-request -s workspace-write)
if [ "$HEADLESS" = "true" ]; then
  APPROVAL_FLAGS=(--dangerously-bypass-approvals-and-sandbox)
  echo ">> HEADLESS mode: bypassing approvals/sandbox (assumes externally sandboxed CI)"
fi

MODEL_FLAGS=()
[ -n "${WIZARD_MODEL:-}" ] && MODEL_FLAGS=(-m "$WIZARD_MODEL")

# ── Run ──────────────────────────────────────────────────────────────────────
# --no-validation: keep the Phase 4b `dbt parse` gate as the single arbiter, so
#   Wizard's internal validation subagent doesn't compete with the SDD gates.
# --json + -o: machine-readable events + final message for the orchestrator.
FULL_PROMPT="Use the ${AGENT} agent. Task ${TASK} for feature ${FEATURE}. ${PROMPT}"

echo ">> wizard exec (agent=${AGENT} task=${TASK})"
set +e
wizard exec \
  --json \
  --no-validation \
  "${APPROVAL_FLAGS[@]}" \
  "${MODEL_FLAGS[@]}" \
  -o "$LAST" \
  "$FULL_PROMPT" > "$EVENTS" 2>&1
RC=$?
set -e

if [ $RC -ne 0 ]; then
  echo "WIZARD_EXEC_FAILED task=${TASK} rc=${RC} events=${EVENTS}" >&2
  echo "   -> orchestrator: apply Smart Retry Protocol using the error in ${EVENTS}" >&2
  exit $RC
fi

# ── Capture diff for the gate (edit-only; orchestrator commits) ───────────────
# `git add -N` makes new untracked files visible to `git diff`; it's intent-to-add
# only (no content staged) and is fully reversible with `git reset`.
git add -N . >/dev/null 2>&1 || true
git diff > "$DIFF" || true

echo "WIZARD_EXEC_OK task=${TASK} diff=${DIFF} last=${LAST} events=${EVENTS}"
echo ">> Review the diff, then commit as: git commit -am '[SDD-${FEATURE}] T-${TASK}: <desc>'"

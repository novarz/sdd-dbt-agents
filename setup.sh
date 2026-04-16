#!/usr/bin/env bash
# setup.sh — Interactive setup for the SDD dbt agents framework
set -euo pipefail

echo "=== SDD dbt Agents Framework — Setup ==="
echo ""

# ─── Check prerequisites ─────────────────────────────────────────────────────
echo "Checking prerequisites..."
MISSING=()

if ! command -v claude &>/dev/null; then
  MISSING+=("claude (Claude Code CLI): https://claude.ai/code")
else
  echo "  claude:    $(claude --version 2>/dev/null | head -1)"
fi

if ! command -v dbt &>/dev/null; then
  MISSING+=("dbt (dbt Core or dbt Platform CLI): https://docs.getdbt.com/docs/core/installation")
else
  echo "  dbt:       $(dbt --version 2>/dev/null | head -1)"
fi

if ! command -v terraform &>/dev/null; then
  MISSING+=("terraform: brew install terraform  OR  https://developer.hashicorp.com/terraform/install")
else
  echo "  terraform: $(terraform version 2>/dev/null | head -1)"
fi

if ! command -v gh &>/dev/null; then
  MISSING+=("gh (GitHub CLI): brew install gh  OR  https://cli.github.com")
else
  echo "  gh:        $(gh --version 2>/dev/null | head -1)"
  if ! gh auth status &>/dev/null; then
    MISSING+=("gh auth: run 'gh auth login' to authenticate")
  fi
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "Missing prerequisites:"
  for m in "${MISSING[@]}"; do
    echo "  - $m"
  done
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup aborted. Install missing prerequisites and re-run."
    exit 1
  fi
fi

echo ""

# ─── Copy config files ───────────────────────────────────────────────────────
if [ ! -f project-config.yaml ]; then
  cp project-config.example.yaml project-config.yaml
  echo "Created project-config.yaml — fill in your values."
else
  echo "project-config.yaml already exists, skipping."
fi

if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  echo "Created .env (chmod 600) — fill in your sensitive credentials."
else
  echo ".env already exists, skipping."
fi

echo ""

# ─── Install dbt agent skills ────────────────────────────────────────────────
echo "To install dbt agent skills, open Claude Code and run:"
echo "  /plugin marketplace add dbt-labs/dbt-agent-skills"
echo "  /plugin install dbt@dbt-agent-marketplace"
echo ""

# ─── Initialize dbt project if needed ────────────────────────────────────────
if [ -f dbt_project.yml ]; then
  echo "dbt project found (dbt_project.yml exists)."
  if [ -f packages.yml ]; then
    echo "Running dbt deps..."
    dbt deps 2>/dev/null || echo "  dbt deps failed — check profiles.yml or run manually."
  fi
else
  echo "No dbt_project.yml found. The orchestrator (Phase 0) will create one when you start."
fi

echo ""

# ─── Initialize Terraform ────────────────────────────────────────────────────
if command -v terraform &>/dev/null; then
  echo "To initialize Terraform after filling project-config.yaml:"
  echo "  source .env"
  echo "  cd terraform/{snowflake|bigquery|databricks}"
  echo "  terraform init"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit project-config.yaml with your project settings"
echo "  2. Edit .env with your sensitive credentials"
echo "  3. Open Claude Code and describe your data need"
echo "  4. The orchestrator will guide you through the SDD workflow"
echo ""

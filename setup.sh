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

if command -v dbtf &>/dev/null || command -v dbt-fusion &>/dev/null; then
  echo "  dbt:       $(dbtf --version 2>/dev/null || dbt-fusion --version 2>/dev/null) (Fusion)"
elif command -v dbt &>/dev/null; then
  echo "  dbt:       $(dbt --version 2>/dev/null | head -1)"
else
  MISSING+=("dbt CLI: https://docs.getdbt.com/docs/core/installation")
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

# ─── Optional: Generate profiles.yml ──────────────────────────────────────────
# Only needed for local execution (dbt Fusion or dbt Core).
# Not needed if using dbt Cloud CLI or only deploying via Phase 6 (Terraform).
if [ -f project-config.yaml ] && [ ! -f profiles.yml ]; then
  echo "profiles.yml is only needed for local dbt execution (Fusion or Core)."
  echo "Not needed if using dbt Cloud CLI or only deploying via Terraform."
  read -p "Generate profiles.yml for local development? (y/N) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/generate-profiles.sh project-config.yaml || echo "  Failed — you can generate it later with: ./scripts/generate-profiles.sh"
  else
    echo "Skipped. To generate later: ./scripts/generate-profiles.sh"
  fi
  echo ""
elif [ -f profiles.yml ]; then
  echo "profiles.yml exists (local development enabled)."
  echo ""
fi

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

# ─── Validate config (if filled) ─────────────────────────────────────────────
if [ -f project-config.yaml ]; then
  echo "Validating project-config.yaml..."
  ./scripts/validate-config.sh project-config.yaml || true
  echo ""
fi

# ─── Optional: CI validation ─────────────────────────────────────────────────
if [ ! -f .github/workflows/validate.yml ] && [ -f ci/validate.yml ]; then
  echo "Optional: GitHub Actions CI validates Terraform syntax, agent consistency,"
  echo "and checks for leaked credentials on every PR."
  read -p "Activate CI validation? (y/N) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p .github/workflows
    cp ci/validate.yml .github/workflows/validate.yml
    echo "CI activated: .github/workflows/validate.yml"
  else
    echo "Skipped. To activate later: cp ci/validate.yml .github/workflows/"
  fi
  echo ""
fi

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

# SDD-dbt-agents — Spec-Driven Development Framework for dbt

A multi-agent framework built on Claude Code that designs, implements, tests, deploys, and monitors dbt projects autonomously — from a business requirement to production in a single session.

The orchestrator (`CLAUDE.md`) coordinates a team of specialized subagents through a structured workflow with human approval gates at each phase:

```
Requirement → Spec → Technical Design → Tasks → Parallel Implementation → Validation → Deploy → Monitor
```

Every artifact is traceable: `requirements.md` traces to business questions, which trace to models, which trace to tests. When your regulator asks "where does this number come from?", the answer is in the spec.

---

## 6 Entry Points

The framework adapts to where you are:

| Route | When to use | What you provide |
|-------|-------------|-----------------|
| **A) New project** | Starting from scratch | Business need in natural language |
| **B) Existing project** | Adding a feature to an existing dbt project | User stories |
| **C) Demo** | Spin up a vertical from a pre-built template | Just pick the vertical |
| **D) Audit** | Health check an existing project | Nothing (inspector reads everything) |
| **E) Ops** | Monitor production, diagnose failures, generate backlog | Nothing (dbt-ops reads via MCP) |
| **F) Contracts** | Already have ODCS data contracts | Business questions + domain rules |
| **G) Generate demo** | Create a fully-implemented demo dbt project in your own GitHub org | Target org/repo, warehouse, dbt Platform account |

---

## 12 Agents

| Agent | Phase | Role |
|-------|-------|------|
| `dbt-inspector` | 0b | Audits existing projects: architecture, health, PII scan, Terraform import |
| `spec-analyst` | 1 | Turns business needs into structured requirements with EARS acceptance criteria |
| `dbt-architect` | 2 | Designs DAG, materializations, contracts, data classification, versioning strategy |
| `dbt-planner` | 3 | Decomposes design into parallelizable, atomic tasks |
| `dbt-source-loader` | 4 | Creates seeds, configures source schemas, verifies source availability |
| `dbt-developer` | 4 | Implements SQL models and YAML schemas following dbt Labs conventions |
| `dbt-tester` | 4 | Generates unit tests (TDD), accepted_values, custom data quality checks |
| `dbt-semantic` | 4 | Creates MetricFlow semantic models, metrics, dimensions, entities |
| `dbt-reviewer` | 5 | Validates implementation against spec, generates attestations (governed+ tier) |
| `dbt-infra` | 6 | Provisions dbt Platform via Terraform, configures MCP server |
| `dbt-ops` | Post-deploy | Monitors production: incident diagnosis, health sweeps, batch review, improvement backlog |
| `orchestrator` | All | Coordinates the full workflow via `CLAUDE.md` |

---

## Governance Tiers

Set `governance.tier` in `project-config.yaml` to match your organization's maturity:

| Tier | For | Key features |
|------|-----|-------------|
| `basic` | Startups, demos | Naming conventions + PK/FK tests |
| `standard` | Production projects | + dbt contracts, PII classification, freshness, model versioning |
| `governed` | Regulated industries | + ODCS contracts (interoperability), audit attestations |
| `enterprise` | Data mesh, multi-team | + centralized metrics library, cross-project governance |

**dbt is always the engine.** ODCS is an interoperability layer for `governed+` — it translates dbt artifacts into/from a standard format for data catalogs and compliance. It never replaces dbt's own tests and contracts.

---

## Enterprise-Ready Features

- **PII detection** — 3-step classification: pattern matching (column names) + LLM judgment (context) + optional data sampling (opt-in). `meta.classification` required on all mart columns: `pii | confidential | internal | public`
- **Source schema governance** — `env_var()` with fallback, per-environment overrides via Terraform `dbtcloud_environment_variable`
- **Model versioning** — Breaking changes on `access: public` models require `versions` block with `deprecation_date`. Reviewer flags unversioned breaking changes as CRITICAL.
- **Source schema drift detection** — `dbt-ops` health sweeps compare source YAML against `information_schema` to detect dropped columns, type changes, and renames before jobs fail
- **Webhook alerting** — `dbtcloud_webhook` on `job.run.completed` triggers Claude Code headless for automated incident diagnosis (resilient: 200 immediately, async processing, idempotency via `eventId`, 60s artifact delay)
- **Batch review** — `dbt-ops` catches up on all runs since last checkpoint (`specs/ops/.last_check`), detects patterns (recurring failures, flaky tests, performance degradation), generates improvement stories
- **Smart retry** — Failed subagents are automatically retried once with the error in the prompt before escalating to the user
- **Multi-provider git** — GitHub (App/deploy key), GitLab (deploy token), Azure DevOps (AAD app)
- **Multi-auth warehouses** — Snowflake (password/keypair), BigQuery (service account/OAuth), Databricks (PAT/OAuth service principal)
- **Terraform import** — `dbtcloud-terraforming` generates import plans for existing dbt Platform projects. Non-destructive: inspector generates the plan, user reviews, infra agent applies.

---

## Warehouse Support

| Warehouse | Terraform | Auth methods |
|-----------|-----------|-------------|
| Snowflake | `terraform/snowflake/` | password, keypair |
| BigQuery | `terraform/bigquery/` | service account, OAuth |
| Databricks | `terraform/databricks/` | PAT token, OAuth/service principal |

---

## Quick Setup

### Prerequisites

```bash
# Claude Code
claude --version   # v2.1.32+

# dbt
dbt --version      # Core, Cloud CLI, or Fusion

# For Phase 6 (deploy to dbt Platform)
terraform --version   # brew install terraform
gh --version          # brew install gh && gh auth login
```

### Install dbt Agent Skills

```bash
# In Claude Code
/plugin marketplace add dbt-labs/dbt-agent-skills
/plugin install dbt@dbt-agent-marketplace
```

### Configure

```bash
# Copy and fill project config (single source of truth)
cp project-config.example.yaml project-config.yaml

# Copy credentials template
cp .env.example .env && chmod 600 .env
```

Key settings in `project-config.yaml`:

```yaml
governance:
  tier: "standard"          # basic | standard | governed | enterprise

warehouse_platform: "snowflake"

dbt_platform:
  account_id: 000
  host_url: "https://YOUR_PREFIX.eu1.dbt.com/api"
  project_name: "my_project"
```

### dbt MCP Server (required for dbt-ops and dbt-inspector)

After Phase 6, the `dbt-infra` agent auto-generates `.mcp.json`. For manual setup:

```json
{
  "mcpServers": {
    "dbt": {
      "command": "uvx",
      "args": ["dbt-mcp"],
      "env": {
        "DBT_HOST": "eu1.dbt.com",
        "MULTICELL_ACCOUNT_PREFIX": "YOUR_PREFIX",
        "DBT_TOKEN": "${DBT_MCP_TOKEN}",
        "DBT_PROD_ENV_ID": "YOUR_ENV_ID"
      }
    }
  }
}
```

> For multi-cell accounts (most common): split `DBT_HOST` and `MULTICELL_ACCOUNT_PREFIX`. Including the prefix in `DBT_HOST` breaks Semantic Layer queries.

---

## Repository Structure

```
├── CLAUDE.md                          ← SDD orchestrator (the brain)
├── project-config.example.yaml        ← Single config entry point
├── .env.example                       ← Credential templates
├── .claude/
│   └── agents/                        ← 11 specialized subagents
├── docs/
│   ├── governance-tiers.md            ← Tier system reference
│   ├── data-classification.md         ← PII patterns and classification guide
│   └── regions.md                     ← dbt Platform regions
├── specs/
│   ├── templates/                     ← Pre-built specs by vertical
│   │   └── banking-loan-risk/         ← Loan portfolio risk (requirements.md ready, Route G generates the full project)
│   ├── backlog/                       ← Improvement stories from dbt-ops
│   └── ops/                           ← Health reports and batch reviews
├── terraform/
│   ├── snowflake/                     ← Snowflake IaC (connection, SL, MCP, webhook)
│   ├── bigquery/                      ← BigQuery IaC
│   └── databricks/                    ← Databricks IaC
└── scripts/
    ├── detect-dbt.sh                  ← Engine detection (Fusion/Cloud CLI/Core)
    ├── generate-profiles.sh           ← profiles.yml generation
    └── validate-config.sh             ← project-config.yaml validation
```

### Branch convention

| Branch | Contents |
|--------|----------|
| `main` | Framework only: orchestrator, agents, Terraform, scripts |

**Project outputs live in separate repos**, not as branches of this repo. Route G creates a new GitHub repo in your org (e.g. `your-org/demo-banking`) with the full dbt project — SQL models, seeds, tests, Semantic Layer, and its own Terraform state.

```bash
# Example: the banking demo lives at
# https://github.com/novarz/demo-banking
# Clone it independently of the framework
git clone https://github.com/novarz/demo-banking
```

---

## Teardown

### Destroy everything (demos, ephemeral environments)

```bash
source .env
cd terraform/{snowflake|bigquery|databricks}
terraform destroy
```

### Keep warehouse data, remove dbt Platform

Useful when other teams consume your tables directly or data retention is required:

```bash
source .env
cd terraform/{snowflake|bigquery|databricks}
terraform destroy
# Warehouse schemas persist until manually dropped
```

---

## Resources

- [dbt Agent Skills](https://github.com/dbt-labs/dbt-agent-skills) — 10 skills for dbt-aware agents
- [dbt MCP Server](https://docs.getdbt.com/docs/dbt-ai/integrate-mcp-claude)
- [Open Data Contract Standard (ODCS)](https://github.com/bitol-io/open-data-contract-standard)
- [datacontract-cli](https://github.com/datacontract/datacontract-cli) — ODCS ↔ dbt converter
- [dbtcloud-terraforming](https://github.com/dbt-labs/dbtcloud-terraforming) — Import existing dbt Platform config to Terraform
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents)
- [Spec-Driven Development with Claude Code](https://alexop.dev/posts/spec-driven-development-claude-code-in-action/)

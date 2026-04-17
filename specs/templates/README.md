# Demo Catalog — Spec Templates

Pre-built specifications for common analytics verticals. Each template contains
approved specs that the SDD orchestrator can use to skip early phases.

## Available Templates

| Template | Phases Included | Description |
|----------|----------------|-------------|
| [banking-loan-risk](banking-loan-risk/) | Phase 1 (requirements) | Loan portfolio risk: NPL ratio, delinquency buckets, IFRS 9 provisions, Semantic Layer metrics |

## Usage

Tell the orchestrator: "quiero montar la demo de banking" or "usa el template de loan risk".

The orchestrator copies the template to `specs/{feature_name}/` and starts from the
first missing phase.

## Adding Templates

1. Complete a full SDD workflow (Phase 1-5) for your vertical
2. Copy the approved specs here
3. Remove environment-specific values (usernames, dates, schema names)
4. Update this README

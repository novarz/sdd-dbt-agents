# Data Classification Guide

All agents in the SDD framework use this guide to classify columns in dbt models.
Classification is **mandatory** for all mart columns via `meta.classification` in YAML.

## Classification Levels

| Level | Label | Description | Example |
|-------|-------|-------------|---------|
| 1 | `pii` | Personally Identifiable Information — can identify a natural person directly or in combination | email, DNI, phone, full name |
| 2 | `confidential` | Sensitive business data — not PII but restricted access | credit score, salary, risk rating, internal pricing |
| 3 | `internal` | Business data — not sensitive but not for external use | branch_id, product_type, segment |
| 4 | `public` | Can be shared externally | aggregated metrics, date ranges, counts |

## PII Detection Patterns

### Direct identifiers (always PII)

| Pattern | PII Type | Examples |
|---------|----------|---------|
| `*email*`, `*correo*` | email | customer_email, correo_electronico |
| `*phone*`, `*telefono*`, `*mobile*`, `*celular*` | phone | phone_number, telefono_contacto |
| `*dni*`, `*nif*`, `*nie*`, `*ssn*`, `*social_security*`, `*passport*` | national_id | dni_cliente, ssn, passport_number |
| `*iban*`, `*account_number*`, `*cuenta*`, `*card_number*`, `*tarjeta*` | financial | iban, account_number, numero_cuenta |
| `*address*`, `*direccion*`, `*street*`, `*calle*`, `*postal*`, `*zip*` | address | home_address, direccion_fiscal, postal_code |
| `*first_name*`, `*last_name*`, `*full_name*`, `*nombre*`, `*apellido*` | name | customer_name, nombre_completo |
| `*date_of_birth*`, `*fecha_nacimiento*`, `*dob*`, `*birth*` | date_of_birth | fecha_nacimiento, dob |
| `*ip_address*`, `*user_agent*`, `*device_id*`, `*mac_address*` | digital_id | ip_address, device_fingerprint |

### Quasi-identifiers (PII when combined)

| Pattern | Risk | Notes |
|---------|------|-------|
| `*gender*`, `*sexo*` | Medium | PII when combined with location + age |
| `*age*`, `*edad*` | Medium | PII when combined with other quasi-identifiers |
| `*nationality*`, `*nacionalidad*` | Medium | PII in small populations |
| `*customer_id*` | Context-dependent | PII in staging (links to real person), not PII in aggregated facts |

### Confidential (not PII but sensitive)

| Pattern | Type | Examples |
|---------|------|---------|
| `*credit_score*`, `*risk_rating*`, `*scoring*` | financial_risk | credit_score, risk_rating |
| `*salary*`, `*income*`, `*sueldo*`, `*ingreso*` | financial_personal | annual_salary, ingresos_mensuales |
| `*balance*`, `*outstanding*`, `*deuda*` | financial_exposure | outstanding_balance, saldo_deudor |
| `*collateral*`, `*garantia*` | financial_asset | collateral_value, valor_garantia |
| `*interest_rate*` (at individual level) | financial_terms | interest_rate (on a specific loan) |
| `*provision*`, `*impairment*`, `*deterioro*` | regulatory | provision_amount (IFRS 9) |

## YAML Convention

```yaml
columns:
  - name: customer_email
    description: "Email del cliente"
    meta:
      classification: "pii"
      pii_type: "email"
      masking_required: true

  - name: risk_rating
    description: "Calificación interna de riesgo"
    meta:
      classification: "confidential"

  - name: product_type
    description: "Tipo de producto de préstamo"
    meta:
      classification: "internal"

  - name: total_loan_count
    description: "Número total de préstamos activos"
    meta:
      classification: "public"
```

## Masking Strategies

| PII Type | Snowflake | BigQuery | Databricks |
|----------|-----------|----------|------------|
| email | `SHA2(email)` or masking policy | Policy tag + column mask | Column mask function |
| phone | Last 4 digits visible | Policy tag | Column mask |
| national_id | Fully masked | Policy tag | Column mask |
| financial (IBAN) | Last 4 digits | Policy tag | Column mask |
| name | Initials only | Policy tag | Column mask |
| address | City only, no street | Policy tag | Column mask |

## Classification Process (3 steps)

Agents apply these steps in order. Each step catches what the previous one missed.

### Step 1: Pattern matching (always runs)

Match column names against the PII and confidential patterns listed above.
Deterministic, fast, covers ~70% of columns. Works on column names in any language
(patterns include Spanish and English variants).

### Step 2: LLM judgment (always runs)

For columns not caught by patterns, the agent uses its understanding of:
- Column name + description
- Model purpose and grain
- Context (staging vs mart, individual vs aggregate)

Examples:
- `id` in `dim_customer` → PII (identifies a person) — classify as `pii`
- `id` in `fct_daily_summary` → internal (aggregate grain, no person) — classify as `internal`
- `code` → could be postal code (PII) or product code (internal) — read description to decide

### Step 3: Data sampling (opt-in only)

**Only runs if `classification.enable_sampling: true` in `project-config.yaml`.**

For columns that remain ambiguous after steps 1-2 (typically `text`/`varchar` columns
with generic names like `notes`, `comments`, `description`, `external_ref`), the agent
samples actual data values to detect PII patterns:

```bash
$DBT_CMD show --inline "
  SELECT DISTINCT {column}
  FROM {{ ref('{model}') }}
  LIMIT {{ var('sampling_limit', 100) }}
"
```

The agent then scans the sampled values for:
- Email patterns (`*@*.*`)
- Phone patterns (digits with dashes/spaces, 9+ chars)
- National ID patterns (country-specific formats)
- IBAN patterns (`[A-Z]{2}[0-9]{2}...`)

**Constraints:**
- Only runs against `classification.sampling_environment` (default: `dev`) — **never prod**
- Maximum `classification.sampling_limit` rows (default: 100)
- Only on unclassified `text`/`varchar` columns — no numeric or date columns
- Results are logged in the review/inspection report, not persisted

## Rules for Agents

1. **dbt-architect**: Must classify all mart columns in `design.md`. Use Step 1 (patterns) + Step 2 (LLM judgment).
2. **dbt-developer**: Must add `meta.classification` to every column in mart YAMLs. Copy from design.md when available. Staging models inherit classification from their sources.
3. **dbt-reviewer**: Must flag mart columns without `meta.classification` as **CRITICAL**. Must flag columns matching PII patterns that are classified below `pii` as **CRITICAL**. Run Step 3 (sampling) only if `classification.enable_sampling: true` in `project-config.yaml`.
4. **dbt-inspector**: Run all 3 steps during project audit. Sampling gives the most accurate PII scan of existing projects.
5. **dbt-ops**: Must alert if production marts expose PII columns without `masking_required: true` or without warehouse-level masking policies applied.

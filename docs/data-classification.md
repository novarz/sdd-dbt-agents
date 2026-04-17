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

## Rules for Agents

1. **dbt-architect**: Must classify all mart columns in `design.md`. Use this guide for pattern matching + context analysis.
2. **dbt-developer**: Must add `meta.classification` to every column in mart YAMLs. Staging models inherit classification from their sources.
3. **dbt-reviewer**: Must flag mart columns without `meta.classification` as **CRITICAL**. Must flag columns matching PII patterns that are classified below `pii` as **CRITICAL**.
4. **dbt-ops**: Must alert if production marts expose PII columns without `masking_required: true` or without warehouse-level masking policies applied.

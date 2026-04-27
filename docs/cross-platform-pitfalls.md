# Cross-Platform Pitfalls

Common issues when deploying the same dbt project across multiple warehouses
(Snowflake, Databricks, BigQuery). Agents should check these proactively.

## SQL Type Compatibility

Standard SQL types behave differently per warehouse. Use portable types in SQL:

| Avoid | Use instead | Notes |
|-------|------------|-------|
| `cast(x as varchar)` | `cast(x as string)` | Databricks requires length for VARCHAR |
| `cast(x as numeric)` | `cast(x as double)` | Databricks treats `numeric` as string |
| `cast(x as integer)` | `cast(x as int)` | Snowflake and Databricks both support `int` |
| `data_type: numeric` (contract) | `data_type: double` | Match what the warehouse actually produces |
| `data_type: integer` (contract) | `data_type: int` | Databricks produces `int`, not `bigint` |
| `data_type: varchar` (contract) | `data_type: string` | Portable across all warehouses |

**Databricks-specific:** VARCHAR without length raises `DATATYPE_MISSING_SIZE` (SQLSTATE 42K01).
Always use `string` for text columns in SQL and contracts.

## Incremental Strategies

| Strategy | Snowflake | Databricks | BigQuery |
|----------|-----------|------------|---------|
| `merge` | ✅ | ✅ | ✅ |
| `delete+insert` | ✅ | ❌ Not supported | ✅ |
| `insert_overwrite` | ❌ | ✅ | ✅ |
| `append` | ✅ | ✅ | ✅ |

**Default recommendation:** use `merge` — it works on all three warehouses.

## dbt_project.yml: `var()` vs `env_var()`

`var()` cannot be used in `dbt_project.yml` configuration sections (seeds, models config)
because the file is parsed before Jinja variables are resolved. Use `env_var()` instead:

```yaml
seeds:
  my_project:
    core_banking:
      +database: "{{ env_var('DBT_SOURCE_DATABASE', 'ANALYTICS') }}"    # ✅
      +schema: "{{ env_var('DBT_SOURCE_SCHEMA_PREFIX', 'raw') }}_core_banking"
      # NOT: "{{ var('source_database') }}"  ← fails at parse time
```

`env_var()` works because OS environment variables are available before Jinja compilation.
See `dbt-developer.md` Known Pitfalls for full details.

## Seed Column Types

Seed `+column_types` in `dbt_project.yml` must use warehouse-compatible types:

| Avoid | Use instead | Reason |
|-------|------------|---------|
| `varchar` | `string` | Databricks requires length |
| `numeric` | `double` | Databricks doesn't know `numeric` |
| `integer` | `int` | Consistent across warehouses |

## Source Freshness on Seed-Based Projects

Seeds have static timestamps in CSV files. `dbt source freshness` always fails on
seed-backed sources because the `loaded_at` field never advances. Options:

1. **Omit freshness** from sources that come from seeds
2. **Skip in jobs**: remove `dbt source freshness` from production jobs for seed projects
3. **Use real sources**: freshness is meaningful only when data is loaded by an ETL process

## Contract Data Types Must Match Warehouse Output

Enforced contracts (`contract: enforced: true`) fail at build time if `data_type` in the
YAML doesn't match what the warehouse SQL produces. Databricks is stricter than Snowflake:

- Snowflake coerces types more freely
- Databricks Delta fails immediately on any mismatch

After porting a project to a new warehouse, run a build and check contract failures
carefully — they tell you exactly which column and what the mismatch is.

## dbt Platform: `force_node_selection`

Some dbt Platform accounts require `force_node_selection = true` on jobs. Without it,
you get HTTP 405 "State aware orchestration is not enabled for this account."

Set it on all jobs in Terraform as a safe default:
```hcl
resource "dbtcloud_job" "daily_prod" {
  force_node_selection = true
  ...
}
```

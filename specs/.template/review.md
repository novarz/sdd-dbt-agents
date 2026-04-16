# {Feature Name} — Review Report

> **Generado por:** dbt-reviewer | **Fecha:** {date}

## Resumen Ejecutivo

- **Estado:** ✅ Aprobado | ⚠️ Aprobado con observaciones | ❌ Requiere cambios
- **Cobertura de requisitos:** {N}/{M} criterios cubiertos
- **Tests:** {passing}/{total} pasando
- **Issues críticos:** {count}
- **Observaciones:** {count}

## Trazabilidad

| Criterio | Test(s) | Estado |
|----------|---------|--------|
| CA-01 | `not_null_fct_X_pk`, `unique_fct_X_pk` | ✅ |
| CA-02 | `test_fct_X__total_calculation` | ✅ |
| CA-03 | — | ❌ Sin cobertura |

## Issues Críticos

1. **[CRITICAL-{NN}]** {descripción} — Archivo: `{path}` — Criterio: CA-{NN}

## Observaciones

1. **[OBS-{NN}]** {descripción} — Impacto: {bajo/medio}

## Métricas de Calidad

| Métrica | Valor | Objetivo | Estado |
|---------|-------|----------|--------|
| PKs con not_null + unique | {N}/{M} | 100% | ✅/❌ |
| FKs con relationships | {N}/{M} | 100% | ✅/❌ |
| Unit tests por campo calculado | {N}/{M} | ≥1 | ✅/❌ |
| Source freshness configurada | {N}/{M} | 100% | ✅/❌ |

## Veredicto

{Approved / Approved with observations / Changes required}

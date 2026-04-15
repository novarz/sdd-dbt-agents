# {Feature Name} — Requirements

> **Generado por:** spec-analyst | **Fecha:** {date} | **Estado:** Pendiente de aprobación

## 1. Contexto y Objetivo

{Descripción del problema de negocio y por qué necesita resolverse ahora}

## 2. User Stories

| ID | Como... | Necesito... | Para que... |
|----|---------|-------------|-------------|
| US-01 | | | |

## 2b. Preguntas de Negocio

Preguntas concretas que el equipo espera poder responder. Cada pregunta guía qué métricas, dimensiones y marts construir.

### Preguntas estratégicas (dirección, mensual/trimestral)

| ID | Pregunta | Quién la hace | Frecuencia | Story |
|----|----------|---------------|------------|-------|
| BQ-01 | | | | |

### Preguntas operativas (día a día, semanal)

| ID | Pregunta | Quién la hace | Frecuencia | Story |
|----|----------|---------------|------------|-------|
| BQ-XX | | | | |

### Preguntas analíticas (self-service, ad-hoc)

| ID | Pregunta | Quién la hace | Frecuencia | Story |
|----|----------|---------------|------------|-------|
| BQ-XX | | | | |

### Mapping: preguntas → métricas y modelos esperados

| Métrica / Modelo | Tipo | Preguntas que responde | Dimensiones necesarias |
|------------------|------|----------------------|----------------------|
| | | | |

## 3. Fuentes de Datos

| Source | Sistema | Schema/Dataset | Tabla | Frecuencia de carga |
|--------|---------|----------------|-------|---------------------|
| | | | | |

## 4. Criterios de Aceptación (EARS)

### CA-01: {nombre}
- **Evento:** Cuando...
- **Acción:** El sistema debe...
- **Resultado:** De modo que...
- **Estado:** Mientras...

## 5. Fuera de Alcance

- {item explícito — evita scope creep}

## 6. Plataforma de Warehouse

| Parámetro | Valor |
|-----------|-------|
| Warehouse | {BigQuery / Snowflake / Databricks / Redshift / DuckDB / TBD} |
| Proyecto/Account | {nombre o TBD} |
| Dataset/Schema por entorno | dev: `dbt_dev_{usuario}` / staging: `dbt_ci` / prod: `analytics_prod` |

## 7. Estrategia de Deployment

### Entornos

| Entorno | Propósito | Dataset/Schema | Cadencia |
|---------|-----------|----------------|----------|
| dev | Desarrollo individual | `dbt_dev_{usuario}` | On-demand |
| staging (CI) | Validación de PR | `dbt_ci` | Trigger en cada PR (Slim CI) |
| prod | Producción | `analytics_prod` | Job nocturno |

### CI/CD
- Slim CI: `dbt build --select state:modified+` con `--defer`
- Tests obligatorios: PR bloqueado si hay tests en `error`

### Job de Producción
- Schedule: {cron}
- Selector: {dbt selector}
- Freshness check: sí
- Alertas: {canal}

### RBAC
| Grupo | Acceso | Permisos |
|-------|--------|----------|
| | | |

## 8. Supuestos y Preguntas Abiertas

- [ ] {pregunta pendiente de respuesta del negocio}

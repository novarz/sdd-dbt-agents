# Análisis de Riesgo de Cartera de Préstamos — Requirements

> **Generado por:** spec-analyst | **Fecha:** 2026-04-15 | **Estado:** Pendiente de aprobación

## 1. Contexto y Objetivo

El equipo de Riesgos necesita una visión unificada del estado de la cartera de préstamos para monitorizar la morosidad, anticipar deterioro de cartera, y cumplir con los reportes regulatorios (CIRBE, EBA). Actualmente los datos se extraen manualmente de Core Banking (Temenos Transact / Fusion) con queries ad-hoc que cada analista mantiene por separado, generando inconsistencias entre departamentos.

El objetivo es crear una **capa analítica estandarizada** en dbt que:
- Centralice la definición de morosidad y provisiones
- Sea la fuente única para dashboards de Riesgos y reportes regulatorios
- Permita análisis self-service por producto, sucursal y segmento
- Se actualice diariamente y sea auditable

## 2. User Stories

| ID | Como... | Necesito... | Para que... |
|----|---------|-------------|-------------|
| US-01 | Director de Riesgos (CRO) | un dashboard con la tasa de morosidad por segmento y producto | pueda reportar al Consejo y al regulador con datos consistentes |
| US-02 | Analista de Riesgos | consultar la evolución de un préstamo individual con su historial de pagos | pueda evaluar si reclasificar un cliente en la siguiente revisión |
| US-03 | Responsable de Recuperaciones | una lista priorizada de préstamos en riesgo de pasar a mora >90 días | pueda asignar gestores de recuperación proactivamente |
| US-04 | Controller Financiero | el cálculo de provisiones por bucket de morosidad alineado con IFRS 9 | pueda alimentar el cierre contable mensual sin ajustes manuales |
| US-05 | Data Analyst | métricas de cartera disponibles en el Semantic Layer | pueda construir análisis ad-hoc sin escribir SQL contra Core Banking |

## 2b. Preguntas de Negocio

### Preguntas estratégicas (Comité de Riesgos, mensual/trimestral)

| ID | Pregunta | Quién la hace | Frecuencia | Story |
|----|----------|---------------|------------|-------|
| BQ-01 | ¿Cuál es la tasa de morosidad (NPL ratio) global y por segmento de cliente? | CRO | Mensual | US-01 |
| BQ-02 | ¿Cómo ha evolucionado la morosidad en los últimos 12 meses? ¿Tendencia alcista o bajista? | CRO | Trimestral | US-01 |
| BQ-03 | ¿Cuál es la exposición total (EAD) por producto de préstamo (hipotecas, consumo, empresas)? | Controller | Trimestral | US-04 |
| BQ-04 | ¿Cuál es la cobertura de provisiones por bucket de días de mora (0-30, 31-60, 61-90, >90)? | Controller | Mensual | US-04 |

### Preguntas operativas (Recuperaciones, semanal)

| ID | Pregunta | Quién la hace | Frecuencia | Story |
|----|----------|---------------|------------|-------|
| BQ-05 | ¿Cuántos préstamos están entre 31-60 días de mora y cuánto capital representan? | Resp. Recuperaciones | Semanal | US-03 |
| BQ-06 | ¿Cuáles son los top 100 préstamos por saldo vivo en riesgo de pasar a mora >90? | Resp. Recuperaciones | Semanal | US-03 |
| BQ-07 | ¿Qué sucursales concentran mayor morosidad relativa a su cartera? | CRO | Mensual | US-01 |

### Preguntas analíticas (self-service, ad-hoc)

| ID | Pregunta | Quién la hace | Frecuencia | Story |
|----|----------|---------------|------------|-------|
| BQ-08 | Dame el historial de pagos del préstamo [X] con los días de retraso en cada cuota | Analista de Riesgos | Ad-hoc | US-02 |
| BQ-09 | ¿Cuál es la distribución de préstamos por rango de LTV (Loan-to-Value) en hipotecas? | Analista de Riesgos | Ad-hoc | US-05 |
| BQ-10 | ¿Cuál es la tasa de recuperación histórica por bucket de morosidad? | Controller | Semestral | US-04 |

### Mapping: preguntas → métricas y modelos esperados

| Métrica / Modelo | Tipo | Preguntas que responde | Dimensiones necesarias |
|------------------|------|----------------------|----------------------|
| `npl_ratio` | Métrica (ratio) | BQ-01, BQ-02 | segment, product_type, branch, metric_time |
| `total_exposure_ead` | Métrica (simple, SUM) | BQ-03 | product_type, segment, metric_time |
| `provision_coverage_ratio` | Métrica (ratio) | BQ-04 | delinquency_bucket, product_type, metric_time |
| `loans_at_risk_count` | Métrica (simple, COUNT) | BQ-05, BQ-06 | delinquency_bucket, branch, metric_time |
| `loans_at_risk_balance` | Métrica (simple, SUM) | BQ-05, BQ-06 | delinquency_bucket, branch, metric_time |
| `recovery_rate` | Métrica (ratio) | BQ-10 | delinquency_bucket, metric_time |
| `fct_loan_daily_snapshot` | Mart (incremental) | BQ-01 a BQ-07 | Grain: 1 fila por préstamo por día |
| `fct_loan_payment` | Mart (incremental) | BQ-08, BQ-10 | Grain: 1 fila por pago |
| `dim_loan` | Dimensión (table) | BQ-03, BQ-06, BQ-09 | Atributos estáticos del préstamo: product_type, origination_date, ltv, collateral_type |
| `dim_customer` | Dimensión (table) | BQ-01, BQ-07 | Atributos del cliente: segment, branch, risk_rating |
| `dim_branch` | Dimensión (table) | BQ-07 | Atributos de sucursal: region, zone |
| `int_loan_delinquency_bands` | Intermediate | BQ-04, BQ-05 | Clasificación por buckets de mora |

## 3. Fuentes de Datos

| Source | Sistema | Schema/Dataset | Tabla | Frecuencia | Volumen estimado |
|--------|---------|----------------|-------|------------|-----------------|
| Core Banking | Temenos Transact (Fusion) | `core_banking` | `loans` | Diaria (batch nocturno) | ~2M filas total |
| Core Banking | Temenos Transact (Fusion) | `core_banking` | `loan_payments` | Diaria (batch nocturno) | ~15M filas/año |
| Core Banking | Temenos Transact (Fusion) | `core_banking` | `customers` | Diaria (batch nocturno) | ~800K filas total |
| Core Banking | Temenos Transact (Fusion) | `core_banking` | `accounts` | Diaria (batch nocturno) | ~3M filas total |
| Datos de Referencia | MDM | `reference_data` | `branches` | Semanal | ~500 filas |
| Datos de Referencia | MDM | `reference_data` | `product_catalog` | Mensual | ~200 filas |

### Columnas clave (loans)
- `loan_id` (STRING) — PK
- `customer_id` (STRING) — FK a customers
- `account_id` (STRING) — FK a accounts
- `product_type` (STRING) — 'mortgage', 'consumer', 'business', 'credit_line'
- `origination_date` (DATE)
- `maturity_date` (DATE)
- `original_amount` (NUMERIC) — importe original en EUR
- `outstanding_balance` (NUMERIC) — saldo vivo actual
- `interest_rate` (NUMERIC) — tipo de interés anual
- `collateral_value` (NUMERIC) — valor de la garantía (hipotecas)
- `loan_status` (STRING) — 'active', 'closed', 'defaulted', 'restructured'
- `risk_rating` (STRING) — calificación interna de riesgo
- `loaded_at` (TIMESTAMP)

### Columnas clave (loan_payments)
- `payment_id` (STRING) — PK
- `loan_id` (STRING) — FK a loans
- `due_date` (DATE) — fecha prevista de pago
- `payment_date` (DATE) — fecha real de pago (NULL si impagado)
- `amount_due` (NUMERIC) — importe previsto
- `amount_paid` (NUMERIC) — importe real pagado
- `principal_component` (NUMERIC)
- `interest_component` (NUMERIC)
- `days_past_due` (INTEGER) — días de retraso (0 si al corriente)
- `payment_status` (STRING) — 'paid', 'partial', 'unpaid', 'written_off'
- `loaded_at` (TIMESTAMP)

### Columnas clave (customers)
- `customer_id` (STRING) — PK
- `customer_type` (STRING) — 'individual', 'business'
- `segment` (STRING) — 'retail', 'premium', 'private_banking', 'sme', 'corporate'
- `branch_id` (STRING) — FK a branches
- `country` (STRING)
- `registration_date` (DATE)
- `is_active` (BOOLEAN)
- `loaded_at` (TIMESTAMP)

### Columnas clave (branches)
- `branch_id` (STRING) — PK
- `branch_name` (STRING)
- `region` (STRING) — 'norte', 'sur', 'este', 'oeste', 'centro'
- `zone` (STRING) — zona comercial
- `is_active` (BOOLEAN)

## 4. Criterios de Aceptación (EARS)

### CA-01: Cálculo de morosidad (NPL)
- **Evento:** Cuando se ejecuta el modelo diariamente
- **Acción:** El sistema clasifica cada préstamo en buckets de mora: al_corriente (0 días), 1-30, 31-60, 61-90, >90
- **Resultado:** La tasa de morosidad (NPL) se calcula como saldo de préstamos >90 días / saldo total de cartera activa
- **Estado:** Solo incluye préstamos con `loan_status` IN ('active', 'restructured')

### CA-02: Clasificación por buckets de mora
- **Evento:** Cuando se calcula el bucket de mora de un préstamo
- **Acción:** El sistema usa el mayor `days_past_due` de las cuotas vencidas no pagadas del préstamo
- **Resultado:** El bucket asignado es determinístico y consistente
- **Estado:** Los buckets válidos son exactamente: 'current', '1_30', '31_60', '61_90', 'over_90'

### CA-03: Snapshot diario
- **Evento:** Cuando se ejecuta el job nocturno
- **Acción:** El sistema genera una foto diaria del estado de cada préstamo activo
- **Resultado:** Se puede consultar el estado de cualquier préstamo en cualquier fecha histórica
- **Estado:** El modelo es incremental — solo procesa los cambios del día

### CA-04: Provisiones IFRS 9
- **Evento:** Cuando el controller consulta las provisiones por bucket
- **Acción:** El sistema aplica porcentajes de provisión configurables por bucket (stage 1, 2, 3)
- **Resultado:** El importe provisionado es la suma de (saldo vivo × % provisión) por bucket
- **Estado:** Los porcentajes de provisión vienen de una tabla de configuración (seed), no hardcodeados

### CA-05: Integridad referencial
- **Evento:** Cuando existen pagos sin préstamo asociado o préstamos sin cliente
- **Acción:** El sistema registra estas anomalías en un modelo de data quality
- **Resultado:** No se incluyen en los cálculos de métricas pero se reportan para investigación

### CA-06: Métricas en Semantic Layer
- **Evento:** Cuando un usuario consulta vía Semantic Layer
- **Acción:** Las métricas `npl_ratio`, `total_exposure_ead`, `provision_coverage_ratio` están disponibles
- **Resultado:** Las consultas permiten filtrar por segmento, producto, sucursal y período temporal
- **Dimensiones requeridas:** segment, product_type, branch, delinquency_bucket, metric_time

### CA-07: Rendimiento y SLA
- **Evento:** Cuando se ejecuta el job de producción nocturno
- **Acción:** El pipeline completo (staging → marts) se ejecuta incrementalmente
- **Resultado:** El tiempo total no supera los 15 minutos
- **Estado:** Datos disponibles para reporting antes de las 07:00 CET

## 5. Fuera de Alcance

- Modelos predictivos de probabilidad de impago (PD) — solo descriptivo, no ML
- Integración con sistemas de scoring externo (CIRBE, bureaus de crédito)
- Cálculo de LGD (Loss Given Default) — se usará un % fijo por producto como proxy
- Reporting regulatorio con formato específico (COREP/FINREP) — se proveen los datos base
- Datos históricos anteriores a la migración a Temenos (antes de 2022)
- Gestión de tipos de cambio — toda la cartera es en EUR

## 6. Estrategia de Deployment

### Entornos

| Entorno | Propósito | Dataset BigQuery | Cadencia |
|---------|-----------|-----------------|----------|
| dev | Desarrollo individual | `dbt_dev_{usuario}` | On-demand (developer) |
| staging (CI) | Validación de PR | `dbt_ci` | Trigger en cada PR (Slim CI) |
| prod | Producción | `analytics_prod` | Job nocturno 03:00 CET |

### CI/CD

- **Slim CI:** Cada PR ejecuta `dbt build --select state:modified+` contra el entorno CI, comparando con los artifacts de producción
- **Defer:** El entorno CI usa `--defer --state prod-artifacts/` para reutilizar tablas de prod no modificadas
- **Tests obligatorios:** El PR no se puede mergear si hay tests en estado `error` (los `warn` son aceptables)

### Job de Producción

- **Schedule:** 03:00 CET, lunes a viernes (los datos de Core Banking se cargan a las 02:00)
- **Selector:** `dbt build -s tag:loan_portfolio_risk`
- **Freshness:** `dbt source freshness` como primer paso — si las fuentes no están frescas, el job falla antes de ejecutar modelos
- **Alertas:** Notificación a #data-alerts en Slack si el job falla o tarda >15 min

### RBAC (si dbt Mesh / Enterprise)

| Grupo | Acceso a modelos | Puede ejecutar |
|-------|-----------------|----------------|
| risk-analysts | Lectura de marts (fct_, dim_) | Jobs de dev |
| risk-data-engineers | Lectura/escritura de staging + intermediate + marts | Jobs de dev, CI, prod |
| controllers | Lectura de marts (solo métricas financieras) | Ninguno (consumidores) |

## 7. Supuestos y Preguntas Abiertas

### Supuestos
- Los datos de Temenos/Fusion se cargan completos antes de las 02:00 CET
- El campo `days_past_due` se calcula en el source system y es fiable
- Los porcentajes de provisión IFRS 9 se mantienen en un seed de dbt versionado en Git
- El segmento del cliente es estable (no cambia frecuentemente)
- Un préstamo solo puede pertenecer a un cliente (relación 1:N customer → loans)

### Preguntas Abiertas
- [ ] ¿Los préstamos reestructurados se incluyen en el cálculo de NPL o se tratan por separado?
- [ ] ¿Necesitamos granularidad mensual o diaria para el snapshot? (diaria requiere más storage)
- [ ] ¿Los porcentajes de provisión son los mismos para todos los productos o varían?
- [ ] ¿Hay un modelo de staging actual en Core Banking que ya limpie datos o partimos de raw?
- [ ] ¿Se requiere anonimización de datos de clientes en el entorno de dev?

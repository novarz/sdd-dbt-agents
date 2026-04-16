# Spec-Driven Development + dbt — Demo Multi-Agente con Claude Code

## Qué es esto

Un framework de agentes IA coordinados que construye proyectos dbt completos a partir de un requisito de negocio, **sin escribir una línea de código manualmente**.

El orquestador (`CLAUDE.md`) dirige un equipo de 7 subagentes especializados a través de un flujo con approval gates humanos en cada fase:

```
Requisito → Spec → Diseño técnico → Tareas → Implementación paralela → Validación → Deploy dbt Platform
```

Cada fase produce artefactos trazables: el `requirements.md` traza a las preguntas de negocio, que trazan a los modelos, que trazan a los tests. Si el regulador pregunta "¿de dónde sale este dato?", la respuesta está en el spec.

**Audiencia:** Equipos de datos en banca, retail y seguros

---

## De dónde vienen los specs

El agente `spec-analyst` (Fase 1) puede derivar los requisitos desde **cualquier fuente de contexto**. No hace falta escribir el spec a mano:

### Lenguaje natural (esta demo)
El punto de entrada más simple: describes la necesidad de negocio en texto libre y el agente genera el `requirements.md` completo.

```
Necesitamos un dashboard de morosidad por segmento con datos diarios
y una lista priorizada de préstamos en riesgo para Recuperaciones.
```

### Proyecto dbt existente
El agente puede leer tu proyecto actual (`dbt_project.yml`, `models/`, `schema.yml`) y generar specs para nuevas features o documentar lo que ya existe.

```
Analiza el proyecto dbt en ./models/ y genera el spec para añadir
métricas de retención de clientes al Semantic Layer.
```

### Metadatos de base de datos
Con acceso al warehouse (vía dbt MCP o SQL directo), el agente puede inspeccionar `information_schema`, catálogos de columnas y estadísticas para entender qué datos existen antes de diseñar los modelos.

```
Conéctate al warehouse y genera el spec de staging para las tablas
del schema core_banking: loans, payments, customers, accounts.
```

### Confluence / Atlassian
Si los requisitos viven en páginas de Confluence o tickets de Jira, el agente los consume directamente vía MCP y los convierte en specs estructurados con user stories y criterios EARS.

```
Lee la página de Confluence "PRD — Riesgo de Cartera Q2 2026" y
genera el requirements.md para el flujo SDD.
```

```
Lee el epic RISK-142 en Jira con todos sus sub-tickets y genera
el spec completo con las user stories del equipo de Riesgos.
```

### Notion
Igual que con Confluence: el agente lee docs de Notion y los transforma en specs accionables para el flujo SDD.

### Combinación de fuentes
El caso más potente — el agente cruza varias fuentes: el PRD en Confluence, los tickets en Jira, el esquema real del warehouse y el proyecto dbt existente, para generar un spec con contexto completo.

```
Lee el epic RISK-142 en Jira, la página "Definiciones de Mora" en
Confluence, e inspecciona las tablas en core_banking en BigQuery.
Genera el requirements.md cruzando las tres fuentes.
```

> **Nota:** Para Jira, Confluence y Notion se necesita el MCP server correspondiente configurado en `.mcp.json`. Ver sección de setup.

---

## Setup

### 1. Prerequisitos

```bash
# Claude Code v2.1.32+
claude --version

# dbt Core o dbt Platform CLI
dbt --version

# Node.js (para skills installer)
node --version
```

**Para Phase 6 (deploy a dbt Platform):**

```bash
# Terraform CLI
terraform --version  # si falta: brew install terraform

# GitHub CLI (autenticado)
gh --version         # si falta: brew install gh
gh auth login
```

> **macOS:** Si no tienes Homebrew → https://brew.sh

### 2. Instalar dbt Agent Skills (en Claude Code)

```bash
# Método recomendado: Plugin marketplace
/plugin marketplace add dbt-labs/dbt-agent-skills
/plugin install dbt@dbt-agent-marketplace

# Para migraciones (opcional, no necesario para la demo):
/plugin install dbt-migration@dbt-agent-marketplace
```

**Skills incluidos en el plugin `dbt`** (se activan automáticamente por contexto):

| Skill | Qué hace | Fase SDD |
|-------|----------|----------|
| `using-dbt-for-analytics-engineering` | Workflow completo: plan → discover → implement → build → verify | 2, 4 |
| `adding-dbt-unit-test` | TDD: mock inputs upstream, validar outputs esperados | 4 |
| `building-dbt-semantic-layer` | MetricFlow: semantic models, métricas (simple/derived/cumulative/ratio/conversion) | 4 |
| `answering-natural-language-questions-with-dbt` | Consultar SL: flowchart SL → SQL compilado → model discovery | 5 |
| `working-with-dbt-mesh` | Governance: contratos, acceso, grupos, versiones, cross-project refs | 2, 5 |
| `troubleshooting-dbt-job-errors` | Diagnóstico de fallos en jobs de la plataforma | 4, 5 |
| `running-dbt-commands` | Ejecución estandarizada de comandos CLI | Todas |
| `fetching-dbt-docs` | Consulta de documentación dbt en formato LLM-friendly | 2 |
| `configuring-dbt-mcp-server` | Configuración del MCP server para Claude/Cursor/VS Code | Setup |

**Alternativa para otros agentes (Cursor, Copilot, etc.):**
```bash
npx skills add dbt-labs/dbt-agent-skills
```

### 2b. Opcional: Contexto específico del proyecto (dbt-skillz)

Auto-genera un skill con tu DAG, columnas, lineage y transformaciones reales:
```bash
pip install dbt-skillz
dbt-skillz compile --project-dir . --output ./.claude/skills/my-project
```

### 3. Configurar dbt MCP Server (opcional, mejora la demo)

Crear `.mcp.json` en la raíz del proyecto:

```json
{
  "mcpServers": {
    "dbt": {
      "command": "uvx",
      "args": ["dbt-mcp"],
      "env": {
        "DBT_HOST": "https://TU_SUBDOMINIO.us1.dbt.com",
        "DBT_TOKEN": "dbtc_TU_TOKEN",
        "DBT_PROD_ENVIRONMENT_ID": "TU_ENV_ID"
      }
    }
  }
}
```

### 4. Copiar este proyecto

```bash
# Copiar estructura a tu proyecto dbt existente
cp CLAUDE.md /path/to/tu-proyecto-dbt/
cp -r .claude/ /path/to/tu-proyecto-dbt/
mkdir -p /path/to/tu-proyecto-dbt/specs/
```

## Estructura del Proyecto

```
tu-proyecto-dbt/
├── CLAUDE.md                          ← Orquestador SDD
├── project-config.example.yaml        ← Config central: warehouse, dbt Platform, schemas, jobs
├── .env.example                       ← Credenciales sensibles (nunca commitear .env)
├── .claude/
│   └── agents/
│       ├── spec-analyst.md            ← Fase 1: Requisitos
│       ├── dbt-architect.md           ← Fase 2: Diseño técnico
│       ├── dbt-planner.md             ← Fase 3: Descomposición en tareas
│       ├── dbt-source-loader.md        ← Fase 4: Preparación de datos fuente
│       ├── dbt-developer.md           ← Fase 4: Implementación SQL/YAML
│       ├── dbt-tester.md              ← Fase 4: Tests genéricos + unit
│       ├── dbt-semantic.md            ← Fase 4: Semantic Layer
│       └── dbt-reviewer.md            ← Fase 5: Validación vs spec
├── specs/
│   └── {feature}/
│       ├── requirements.md
│       ├── design.md
│       ├── tasks.md
│       ├── review.md
│       └── progress.md
├── terraform/                         ← Fase 6: Infraestructura dbt Platform
│   ├── snowflake/                     ← Snowflake: conexión, credenciales, SL
│   ├── bigquery/                      ← BigQuery: conexión, credenciales, SL
│   └── databricks/                    ← Databricks: conexión, credenciales, SL
├── models/
│   ├── staging/
│   ├── intermediate/
│   └── marts/
└── dbt_project.yml
```

## Guión de la Demo (25 min)

### Acto 1: El Problema (2 min)

> "El Comité de Riesgos os pide esto:
> *'Necesitamos un dashboard unificado de morosidad por segmento y producto con datos diarios. Y que Recuperaciones tenga una lista priorizada de préstamos en riesgo.'*
> Hoy cada analista tiene su propia query contra Core Banking. Cada uno calcula la mora diferente. El regulador pide consistencia. ¿Cuánto tardáis? ¿3 semanas? ¿Un mes?"

### Acto 2: Spec-Driven Development (4 min)

Abrir Claude Code y escribir:

```
Necesitamos construir la capa analítica de riesgo de cartera de préstamos.
Fuentes en BigQuery desde Core Banking (Temenos/Fusion): loans, loan_payments,
customers, accounts, branches. Necesitamos tasa de morosidad (NPL ratio) por
segmento y producto, provisiones por bucket IFRS 9, y lista priorizada de
préstamos en riesgo para Recuperaciones. El equipo de Riesgos necesita métricas
en el Semantic Layer para análisis self-service.
```

**Mostrar:** Cómo el `spec-analyst` genera `requirements.md` con:
- 5 user stories (CRO, Analista de Riesgos, Recuperaciones, Controller, Data Analyst)
- 10 preguntas de negocio categorizadas (estratégicas, operativas, self-service)
- Mapping BQ → métricas y marts (esto es la clave: la tabla que dice qué construir)
- Estrategia de deployment (entornos, Slim CI, job nocturno, RBAC)
- Criterios EARS trazables a tests

Hacer pause en el **approval gate**.

> "Fijaos: el agente NO ha escrito SQL. Ha escrito el contrato que va al Comité de Riesgos. Las preguntas de negocio son las que dictan qué métricas y marts construimos — no al revés."

### Acto 3: Diseño Técnico (3 min)

Aprobar los requisitos. Mostrar cómo `dbt-architect` genera:
- DAG: sources → stg_core_banking__loans/payments/customers → int_loan_delinquency_bands → fct_loan_daily_snapshot + dim_loan + dim_customer
- Contratos de modelo con data types para los marts
- Estrategia de materialización (snapshot incremental por día, dims como table)
- Seed de provisiones IFRS 9 (configurable, no hardcodeado)
- Configuración de entornos y Slim CI con deferral a prod artifacts
- RBAC por grupo

> "El diseño incluye la infra de deployment. No es un afterthought — es parte del contrato técnico que el humano aprueba."

### Acto 4: Implementación Paralela (6 min)

Aprobar el diseño y las tareas. Mostrar cómo se lanzan subagentes en paralelo:

```
[dbt-developer] → dbt show -s source:core_banking.loans --limit 5          ← previewing data
[dbt-developer] → Creando stg_core_banking__loans...                        ✓ dbt build passed
[dbt-developer] → Creando stg_core_banking__loan_payments...                ✓ dbt build passed
[dbt-developer] → Creando stg_core_banking__customers...                    ✓ dbt build passed
[dbt-developer] → Creando int_loan_delinquency_bands (buckets IFRS 9)...    ✓ dbt build passed
[dbt-developer] → Creando fct_loan_daily_snapshot (incremental + contrato)  ✓ dbt build passed
[dbt-developer] → dbt show → verificando grain 1 fila/préstamo/día         ✓ verified
[dbt-tester]    → Unit test: clasificación de buckets de mora...            ✓ passed
[dbt-tester]    → Unit test: cálculo NPL ratio...                          ✓ passed
[dbt-tester]    → Tests genéricos (PKs, FKs, accepted_values)...           ✓ 18 tests passed
[dbt-semantic]  → Creando semantic model: npl_ratio, exposure, provisions   ✓ dbt parse passed
```

> "El `dbt-tester` ha escrito los unit tests antes de que exista la lógica de negocio — es TDD. Los buckets de mora se testean con datos mockeados: si un préstamo tiene 45 días de impago, ¿cae en el bucket '31_60'? El unit test lo verifica."

### Acto 5: Validación (3 min)

Mostrar el review report con:
- Matriz de trazabilidad: CA-01 (NPL) → unit test + ratio metric | CA-04 (provisiones) → seed + unit test
- Cobertura: 100% PKs, 100% FKs, unit tests para buckets y NPL
- Governance check: contratos enforced en todos los marts, RBAC definido
- Estado: ✅ Aprobado

> "El reviewer ha validado contra el spec original. Cada métrica traza a una pregunta de negocio, cada pregunta traza a una user story. Si el regulador pregunta '¿de dónde sale este dato?', la respuesta está en el spec."

### Acto 6: El Mensaje (4 min)

> "¿Qué acabáis de ver?"
>
> 1. **Governance by design** — Approval gates, trazabilidad pregunta→métrica→test→código
> 2. **Reproducible** — Los skills de dbt Labs codifican best practices, no dependen del seniority
> 3. **Velocidad** — De requisito del Comité de Riesgos a modelo en producción en una sesión
> 4. **Auditabilidad** — El spec es el artefacto que enseñas al regulador
> 5. **Deployment incluido** — Entornos, CI/CD, RBAC no son un afterthought
>
> "Esto es dbt Platform + AI agents para un equipo de datos bancario."

### Acto 6b (bonus): Deploy a dbt Platform con Terraform (3 min)

Si se quiere mostrar el aprovisionamiento completo:

```bash
cp project-config.example.yaml project-config.yaml   # rellenar config del proyecto
cp .env.example .env && chmod 600 .env                # rellenar credenciales sensibles
source .env
# El agente dbt-infra lee project-config.yaml y genera terraform.tfvars automáticamente
```

El agente `dbt-infra` provisiona automáticamente via Terraform:
- Proyecto dbt Platform + conexión al warehouse (Snowflake, BigQuery o Databricks)
- Entornos Development / Staging / Production (con branch custom)
- Job diario (`dbt build`) + Slim CI (PR webhook)
- Semantic Layer configuration + service token
- `.mcp.json` con la configuración del dbt MCP Server

**Activación del Semantic Layer** (requiere un run exitoso previo):
```bash
terraform apply -var="enable_semantic_layer=true"
```

> El GitHub App installation ID se auto-descubre via `gh api orgs/{org}/installations` — no hace falta buscarlo manualmente.

### Acto 7 (bonus): Consulta en vivo (3 min)

Si el MCP está configurado, hacer una consulta real al Semantic Layer:

```
¿Cuál es la tasa de morosidad por segmento de cliente este mes?
```

Mostrar cómo el skill `answering-natural-language-questions-with-dbt` sigue el flowchart:
Semantic Layer → list_metrics → query_metrics → resultado

## Casos de uso por sector

| Sector | Caso de uso | Sources típicos | Ángulo |
|--------|-------------|-----------------|--------|
| Banca | Riesgo de cartera de préstamos (esta demo) | Core Banking → BigQuery/Snowflake | Governance + regulación |
| Banca | Dashboard de banca digital + Semantic Layer | Core Banking → BigQuery | Self-service analytics |
| Banca / DataOps | Observabilidad de pipelines dbt Platform + alertas | Admin API + webhooks | DataOps / SRE |
| Retail | Forecast de demanda por tienda/SKU | ERP → BigQuery | Incremental a escala |
| Seguros | Análisis de siniestralidad por producto/canal | Core Seguros → BigQuery | IFRS 17 + provisiones |

## Estructura del repositorio

Este repo sigue una convención de branches para separar el punto de partida del resultado:

| Branch | Contenido |
|--------|-----------|
| `main` | Solo la meta-capa: `CLAUDE.md`, agentes, README. Lo que clonas antes de empezar. |
| `demo/{feature}` | Resultado tras correr el flujo SDD completo: modelos SQL, tests, YAML, semantic layer. |

Para ver la diferencia entre antes y después:
```bash
git diff main...demo/loan-portfolio-risk
```

## Teardown / Cleanup

Para desmontar la infraestructura aprovisionada por el framework:

```bash
# 1. Destruir recursos de dbt Platform (proyecto, entornos, jobs, SL)
source .env
cd terraform/{snowflake|bigquery|databricks}
terraform destroy

# 2. Limpiar datos en el warehouse (opcional — seeds y modelos)
dbt run-operation drop_schema --args '{schema: dbt_myproject_dev}'
dbt run-operation drop_schema --args '{schema: dbt_myproject_staging}'
dbt run-operation drop_schema --args '{schema: dbt_myproject_prod}'

# 3. Limpiar ficheros locales
rm -r project-config.yaml .env .mcp.json terraform/*/terraform.tfstate*
```

> `terraform destroy` elimina el proyecto de dbt Platform y todos sus recursos, pero NO borra datos del warehouse. Los schemas y tablas creados por dbt persisten hasta que se borren manualmente.

## Recursos

- [dbt Agent Skills (repo oficial)](https://github.com/dbt-labs/dbt-agent-skills) — 10 skills en 2 plugins
- [Blog: Make your AI better at data work with dbt's agent skills](https://docs.getdbt.com/blog/dbt-agent-skills)
- [dbt MCP Server](https://docs.getdbt.com/docs/dbt-ai/integrate-mcp-claude)
- [dbt-skillz (auto-genera skill de tu proyecto)](https://github.com/atlasfutures/dbt-skillz)
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Spec-Driven Development con Claude Code](https://alexop.dev/posts/spec-driven-development-claude-code-in-action/)
- [cc-sdd Framework](https://github.com/gotalab/cc-sdd) — SDD multi-agente en español
- [Webinar dbt Agent Skills (22-23 abril 2026)](https://docs.getdbt.com/) — Ship smarter agents with dbt Agent Skills

---
name: sdd-execution-contract
description: >
  Apply the SDD framework's execution rules when implementing a dbt model, test, or
  semantic task: naming conventions, test ownership boundaries, and the edit-only/
  no-commit contract. Use whenever building or modifying dbt SQL/YAML as part of an
  SDD Phase 4/5 task, regardless of whether the executor is a Claude Code subagent or
  a dbt Wizard headless agent.
---

# SDD execution contract

This skill is the single source of truth for the rules that Phase 4/5 executors follow.
It is portable Agent Skills format, so it is read by both Claude Code subagents and dbt
Wizard (`.agents/skills/` and `.claude/skills/` compatibility path). Keep the rule here —
do not duplicate it inside individual agent definitions.

## Scope

You are implementing **one atomic, already-approved task** from `tasks.md`. Do not
re-plan, re-scope, or implement adjacent tasks. The orchestrator decomposed and gated
the work already — your job is to execute exactly what the task describes.

## Naming conventions (dbt Labs)

- `stg_<source>__<entity>` — staging (1:1 with source, light cleanup)
- `int_<entity>_<verb>` — intermediate (business logic, not exposed)
- `fct_<entity>` / `dim_<entity>` — marts (facts and dimensions)
- Sources declared in `_sources.yml`; models documented in a co-located `_<dir>.yml`.

## Test ownership (do NOT cross this line)

| Test type | Owner | Where |
|-----------|-------|-------|
| `not_null`, `unique` (PKs), `relationships` (FKs) | **developer** | model YAML, written at model creation |
| `accepted_values`, unit tests, custom data-quality tests | **tester** (`test_writer`) | separate test YAML / `tests/` |

- If you are the **developer**: write PK/FK/not_null in the model YAML. Do **not** write
  `accepted_values`, unit tests, or custom DQ tests — those belong to the tester.
- If you are the **tester** (`test_writer`): write `accepted_values`, unit tests, and
  custom DQ checks. Do **not** touch the developer's PK/FK/not_null tests.

## Edit-only / no-commit contract

- **Edit files only. Do NOT run `git commit`, `git add`, or create branches.**
- The **orchestrator** commits after your task passes, using the traceable message
  `[SDD-{feature}] T-{ID}: {description}`. If you commit yourself, you break the
  requirement→code traceability the framework depends on.
- Before finishing, make sure the project still parses (`dbt parse`). Report what you
  changed and why; leave the working tree with your edits staged-or-unstaged but
  uncommitted.

## Validation

- Prefer warehouse-aware validation when available (dbt Wizard's metadata engine /
  `validation` agent, or `dbt show` / `dbt build --select` in Claude Code).
- Do not invent source tables. If a source is missing, follow the data strategy in
  `requirements.md` (seeds / demo scripts / external load) — do not silently hardcode.

# Contributing

## Adding a new agent

1. Create `.claude/agents/{agent-name}.md` with frontmatter:
   ```yaml
   ---
   name: {agent-name}
   description: >
     One-line description of what this agent does.
   tools: Read, Write, Edit, Bash, Glob, Grep
   model: sonnet   # or opus for analysis/judgment tasks
   ---
   ```
2. Define the agent's process, output format, and critical rules
3. Add the agent to the appropriate phase in `CLAUDE.md`
4. Update the Model Selection table in `CLAUDE.md`

## Adding a new warehouse

1. Create `terraform/{warehouse}/` with:
   - `providers.tf` — dbtcloud provider + null (for preflight)
   - `variables.tf` — shared vars + warehouse-specific connection vars
   - `main.tf` — preflight + project + repo + connection + credentials + environments + jobs + semantic layer
   - `outputs.tf` — project_id, environment IDs, SL token
2. Add the warehouse section to `project-config.example.yaml`
3. Add the warehouse credentials to `.env.example`
4. Update `dbt-infra.md` Step 3 mapping table
5. Update `README.md` terraform structure section

## Modifying the SDD workflow

1. All phase definitions live in `CLAUDE.md`
2. Spec templates live in `specs/.template/`
3. Agent definitions live in `.claude/agents/`
4. Keep phase numbering consistent across all three locations
5. If adding a new phase, update `specs/.template/progress.md`

## Conventions

- Terraform: one directory per warehouse, no shared modules
- Agents: opus for analysis, sonnet for execution
- Specs: Spanish if the user communicates in Spanish
- Commits: `[SDD-{feature}] Phase {N} Task {ID}: {description}`

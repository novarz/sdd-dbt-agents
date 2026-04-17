# ─── Preflight: validate Snowflake credentials ────────────────────────────────
# Validates credentials before creating resources to prevent account lockout
# from repeated dbt job failures with wrong passwords.
# Requires snow CLI or snowsql. If neither is available, skips with a warning.
# Set skip_preflight_validation = true to bypass entirely.

resource "null_resource" "validate_snowflake" {
  count = var.skip_preflight_validation ? 0 : 1

  triggers = {
    snowflake_user    = var.snowflake_user
    snowflake_account = var.snowflake_account
  }

  provisioner "local-exec" {
    command = <<-EOT
      if command -v snow &>/dev/null; then
        echo "Validating Snowflake credentials via snow CLI..."
        snow connection test \
          --account "${var.snowflake_account}" \
          --user "${var.snowflake_user}" \
          --password "${var.snowflake_password}" \
          --warehouse "${var.snowflake_warehouse}" \
          --database "${var.snowflake_database}" \
          2>&1 || { echo "ERROR: Snowflake credential validation failed. Check snowflake_user and snowflake_password."; exit 1; }
      elif command -v snowsql &>/dev/null; then
        echo "Validating Snowflake credentials via snowsql..."
        snowsql \
          -a "${var.snowflake_account}" \
          -u "${var.snowflake_user}" \
          --password "${var.snowflake_password}" \
          -w "${var.snowflake_warehouse}" \
          -d "${var.snowflake_database}" \
          -q "SELECT 1" \
          2>&1 || { echo "ERROR: Snowflake credential validation failed. Check snowflake_user and snowflake_password."; exit 1; }
      else
        echo "WARNING: Neither 'snow' nor 'snowsql' CLI found. Skipping credential validation."
        echo "Install: brew install snowflake-cli  OR  brew install --cask snowflake-snowsql"
        echo "Without validation, wrong credentials may cause account lockout."
      fi
      echo "Preflight check complete."
    EOT
  }
}

# ─── Project ──────────────────────────────────────────────────────────────────

resource "dbtcloud_project" "this" {
  name       = var.project_name
  depends_on = [null_resource.validate_snowflake]
}

# ─── GitHub App installation ID discovery ────────────────────────────────────
# If github_installation_id is not set in tfvars, auto-discovers it via the
# GitHub API using gh CLI and GITHUB_ORG env var.

data "external" "github_installation" {
  count   = var.github_installation_id == null ? 1 : 0
  program = ["bash", "-c", <<-EOT
    gh auth refresh -h github.com -s admin:org 2>/dev/null || true
    if [ -n "$GITHUB_ORG" ]; then
      INSTALL_ID=$(gh api "orgs/$GITHUB_ORG/installations" \
        --jq '.installations[] | select(.app_slug | test("dbt")) | .id' 2>/dev/null | head -1)
    fi
    if [ -z "$INSTALL_ID" ]; then
      echo '{"error": "Could not auto-discover. Set github_installation_id in project-config.yaml. See docs/find-github-installation-id.md"}' >&2
      echo '{"id": "0"}'
    else
      echo "{\"id\": \"$INSTALL_ID\"}"
    fi
  EOT
  ]
}

locals {
  github_installation_id = var.github_installation_id != null ? var.github_installation_id : (
    tonumber(data.external.github_installation[0].result.id)
  )
}

# ─── Repository ───────────────────────────────────────────────────────────────

resource "dbtcloud_repository" "this" {
  project_id             = dbtcloud_project.this.id
  remote_url             = var.git_remote_url
  git_clone_strategy     = var.git_clone_strategy
  github_installation_id = local.github_installation_id
}

# ─── Global connection (Snowflake) ────────────────────────────────────────────

resource "dbtcloud_global_connection" "snowflake" {
  name = "Snowflake Terraform"

  snowflake = {
    account   = var.snowflake_account
    database  = var.snowflake_database
    warehouse = var.snowflake_warehouse
    role      = var.snowflake_role != "" ? var.snowflake_role : null
  }
}

# ─── Link repository to project ──────────────────────────────────────────────

resource "dbtcloud_project_repository" "this" {
  project_id    = dbtcloud_project.this.id
  repository_id = dbtcloud_repository.this.repository_id
}

# ─── Snowflake credentials ────────────────────────────────────────────────────

resource "dbtcloud_snowflake_credential" "development" {
  project_id  = dbtcloud_project.this.id
  auth_type   = "password"
  num_threads = 4
  user        = var.snowflake_user
  password    = var.snowflake_password
  schema      = "${var.schema_prefix}_${var.schema_development}"
}

resource "dbtcloud_snowflake_credential" "staging" {
  project_id  = dbtcloud_project.this.id
  auth_type   = "password"
  num_threads = 16
  user        = var.snowflake_user
  password    = var.snowflake_password
  schema      = "${var.schema_prefix}_${var.schema_staging}"
}

resource "dbtcloud_snowflake_credential" "production" {
  project_id  = dbtcloud_project.this.id
  auth_type   = "password"
  num_threads = 16
  user        = var.snowflake_user
  password    = var.snowflake_password
  schema      = "${var.schema_prefix}_${var.schema_production}"
}

# ─── Environments ─────────────────────────────────────────────────────────────

resource "dbtcloud_environment" "development" {
  project_id        = dbtcloud_project.this.id
  name              = "Development"
  dbt_version       = var.dbt_version
  type              = "development"
  credential_id     = dbtcloud_snowflake_credential.development.credential_id
  connection_id     = dbtcloud_global_connection.snowflake.id
  use_custom_branch = true
  custom_branch     = var.git_branch

  depends_on = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "staging" {
  project_id        = dbtcloud_project.this.id
  name              = "Staging"
  dbt_version       = var.dbt_version
  type              = "deployment"
  deployment_type   = "staging"
  credential_id     = dbtcloud_snowflake_credential.staging.credential_id
  connection_id     = dbtcloud_global_connection.snowflake.id
  use_custom_branch = true
  custom_branch     = var.git_branch

  depends_on = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "production" {
  project_id        = dbtcloud_project.this.id
  name              = "Production"
  dbt_version       = var.dbt_version
  type              = "deployment"
  deployment_type   = "production"
  credential_id     = dbtcloud_snowflake_credential.production.credential_id
  connection_id     = dbtcloud_global_connection.snowflake.id
  use_custom_branch = true
  custom_branch     = var.git_branch

  depends_on = [dbtcloud_repository.this]
}

# ─── Job: Daily Build (Staging) ───────────────────────────────────────────────

resource "dbtcloud_job" "daily" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.staging.environment_id
  name           = "Daily Build"
  execute_steps  = ["dbt build"]
  dbt_version    = var.dbt_version
  generate_docs  = true

  schedule_type  = "every_day"
  schedule_hours = var.daily_job_schedule_hours

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    schedule             = true
    on_merge             = false
  }
}

# ─── Job: Daily Build (Production) ───────────────────────────────────────────

resource "dbtcloud_job" "daily_prod" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.production.environment_id
  name           = "Daily Build (Production)"
  execute_steps  = ["dbt build --exclude resource_type:unit_test"]
  dbt_version    = var.dbt_version
  generate_docs  = true

  schedule_type  = "every_day"
  schedule_hours = var.daily_job_schedule_hours

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    schedule             = true
    on_merge             = false
  }
}

# ─── Job: Slim CI ─────────────────────────────────────────────────────────────

resource "dbtcloud_job" "slim_ci" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.staging.environment_id
  name           = "Slim CI"
  execute_steps  = ["dbt build --select state:modified+"]
  dbt_version    = var.dbt_version

  # Defer to the staging environment state so Slim CI only runs modified nodes
  deferring_environment_id = dbtcloud_environment.staging.environment_id

  # Show what changed vs the deferred state
  run_compare_changes = true

  triggers = {
    github_webhook       = true
    git_provider_webhook = true
    schedule             = false
    on_merge             = false
  }
}

# ─── Semantic Layer ───────────────────────────────────────────────────────────
# Requires a successful production job run before applying.
# Step 1: terraform apply (enable_semantic_layer = false, default)
# Step 2: trigger and wait for a successful production job run
# Step 3: terraform apply -var="enable_semantic_layer=true"

resource "dbtcloud_semantic_layer_configuration" "this" {
  count          = var.enable_semantic_layer ? 1 : 0
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.production.environment_id
}

resource "dbtcloud_snowflake_semantic_layer_credential" "this" {
  count = var.enable_semantic_layer ? 1 : 0

  configuration = {
    project_id      = dbtcloud_project.this.id
    name            = "Snowflake SL Credential"
    adapter_version = "snowflake_v0"
  }

  credential = {
    project_id  = dbtcloud_project.this.id
    auth_type   = "password"
    num_threads = 8
    user        = var.snowflake_user
    password    = var.snowflake_password
    schema      = "${var.schema_prefix}_${var.schema_production}"
    database    = var.snowflake_database
  }
}

resource "dbtcloud_service_token" "semantic_layer" {
  name = "${var.project_name}_semantic_layer"

  service_token_permissions {
    permission_set = "semantic_layer_only"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }

  service_token_permissions {
    permission_set = "metadata_only"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }
}

resource "dbtcloud_semantic_layer_credential_service_token_mapping" "this" {
  count                        = var.enable_semantic_layer ? 1 : 0
  project_id                   = dbtcloud_project.this.id
  semantic_layer_credential_id = dbtcloud_snowflake_semantic_layer_credential.this[0].id
  service_token_id             = dbtcloud_service_token.semantic_layer.id
}

# ─── MCP Service Token ───────────────────────────────────────────────────────
# Dedicated token for the dbt MCP server used by Claude Code agents.
# Broader permissions than the SL token: metadata, semantic layer, job admin.

resource "dbtcloud_service_token" "mcp" {
  name = "${var.project_name}_mcp"

  service_token_permissions {
    permission_set = "metadata_only"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }

  service_token_permissions {
    permission_set = "semantic_layer_only"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }

  service_token_permissions {
    permission_set = "job_admin"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }

  service_token_permissions {
    permission_set = "developer"
    project_id     = dbtcloud_project.this.id
    all_projects   = false
  }
}

# Map the MCP token to the SL credential so agents can query metrics
resource "dbtcloud_semantic_layer_credential_service_token_mapping" "mcp" {
  count                        = var.enable_semantic_layer ? 1 : 0
  project_id                   = dbtcloud_project.this.id
  semantic_layer_credential_id = dbtcloud_snowflake_semantic_layer_credential.this[0].id
  service_token_id             = dbtcloud_service_token.mcp.id
}

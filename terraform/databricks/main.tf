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

# ─── Preflight: validate Databricks credentials ──────────────────────────────
# Verifies the PAT token can reach the Databricks workspace.
# Uses curl (always available). No lockout risk with PAT tokens.

resource "null_resource" "validate_databricks" {
  count = var.skip_preflight_validation ? 0 : 1

  triggers = {
    databricks_host = var.databricks_host
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating Databricks credentials..."
      HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" \
        -H "Authorization: Bearer ${var.databricks_token}" \
        "${var.databricks_host}/api/2.0/clusters/list")
      if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "ERROR: Databricks credential validation failed (HTTP $HTTP_CODE). Check databricks_token."
        exit 1
      elif [ "$HTTP_CODE" != "200" ]; then
        echo "WARNING: Databricks returned HTTP $HTTP_CODE. This may be a network issue — proceeding."
      else
        echo "Databricks credentials validated OK."
      fi
      echo "Preflight check complete."
    EOT
  }
}

# ─── Project ──────────────────────────────────────────────────────────────────

resource "dbtcloud_project" "this" {
  name       = var.project_name
  depends_on = [null_resource.validate_databricks]
}

# ─── Repository ───────────────────────────────────────────────────────────────

resource "dbtcloud_repository" "this" {
  project_id             = dbtcloud_project.this.id
  remote_url             = var.git_remote_url
  git_clone_strategy     = var.git_clone_strategy
  github_installation_id = local.github_installation_id

}

# ─── Global connection (Databricks) ──────────────────────────────────────────

resource "dbtcloud_global_connection" "databricks" {
  name = "Databricks Terraform"

  databricks = {
    host      = var.databricks_host
    http_path = var.databricks_http_path
    catalog   = var.databricks_catalog
  }
}

# ─── Link repository to project ──────────────────────────────────────────────

resource "dbtcloud_project_repository" "this" {
  project_id    = dbtcloud_project.this.id
  repository_id = dbtcloud_repository.this.repository_id
}

# ─── Databricks credentials ──────────────────────────────────────────────────

resource "dbtcloud_databricks_credential" "development" {
  project_id = dbtcloud_project.this.id
  adapter_id = dbtcloud_global_connection.databricks.id
  target_name = "development"
  token       = var.databricks_token
  schema      = "${var.schema_prefix}_${var.schema_development}"
  catalog     = var.databricks_catalog
}

resource "dbtcloud_databricks_credential" "staging" {
  project_id = dbtcloud_project.this.id
  adapter_id = dbtcloud_global_connection.databricks.id
  target_name = "staging"
  token       = var.databricks_token
  schema      = "${var.schema_prefix}_${var.schema_staging}"
  catalog     = var.databricks_catalog
}

resource "dbtcloud_databricks_credential" "production" {
  project_id = dbtcloud_project.this.id
  adapter_id = dbtcloud_global_connection.databricks.id
  target_name = "production"
  token       = var.databricks_token
  schema      = "${var.schema_prefix}_${var.schema_production}"
  catalog     = var.databricks_catalog
}

# ─── Environments ─────────────────────────────────────────────────────────────

resource "dbtcloud_environment" "development" {
  project_id        = dbtcloud_project.this.id
  name              = "Development"
  dbt_version       = var.dbt_version
  type              = "development"
  credential_id     = dbtcloud_databricks_credential.development.credential_id
  connection_id     = dbtcloud_global_connection.databricks.id
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
  credential_id     = dbtcloud_databricks_credential.staging.credential_id
  connection_id     = dbtcloud_global_connection.databricks.id
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
  credential_id     = dbtcloud_databricks_credential.production.credential_id
  connection_id     = dbtcloud_global_connection.databricks.id
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

resource "dbtcloud_databricks_semantic_layer_credential" "this" {
  count = var.enable_semantic_layer ? 1 : 0

  configuration = {
    project_id      = dbtcloud_project.this.id
    name            = "Databricks SL Credential"
    adapter_version = "databricks_v0"
  }

  credential = {
    project_id = dbtcloud_project.this.id
    adapter_id = dbtcloud_global_connection.databricks.id
    token      = var.databricks_token
    schema     = "${var.schema_prefix}_${var.schema_production}"
    catalog    = var.databricks_catalog
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
  semantic_layer_credential_id = dbtcloud_databricks_semantic_layer_credential.this[0].id
  service_token_id             = dbtcloud_service_token.semantic_layer.id
}

# ─── MCP Service Token ───────────────────────────────────────────────────────

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

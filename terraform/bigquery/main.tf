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

# ─── Project ──────────────────────────────────────────────────────────────────

resource "dbtcloud_project" "this" {
  name = var.project_name
}

# ─── Repository ───────────────────────────────────────────────────────────────

resource "dbtcloud_repository" "this" {
  project_id             = dbtcloud_project.this.id
  remote_url             = var.git_remote_url
  git_clone_strategy     = var.git_clone_strategy
  github_installation_id = local.github_installation_id

}

# ─── Global connection (BigQuery) ─────────────────────────────────────────────

resource "dbtcloud_global_connection" "bigquery" {
  name = "BigQuery Terraform"

  bigquery = {
    gcp_project_id              = var.gcp_project_id
    timeout_seconds             = var.bigquery_timeout_seconds
    private_key_id              = var.bigquery_private_key_id
    private_key                 = var.bigquery_private_key
    client_email                = var.bigquery_client_email
    client_id                   = var.bigquery_client_id
    auth_uri                    = var.bigquery_auth_uri
    token_uri                   = var.bigquery_token_uri
    auth_provider_x509_cert_url = var.bigquery_auth_provider_x509_cert_url
    client_x509_cert_url        = var.bigquery_client_x509_cert_url
    retries                     = var.bigquery_retries
    location                    = var.gcp_location
  }
}

# ─── Link repository to project ──────────────────────────────────────────────

resource "dbtcloud_project_repository" "this" {
  project_id    = dbtcloud_project.this.id
  repository_id = dbtcloud_repository.this.repository_id
}

# ─── BigQuery credentials ────────────────────────────────────────────────────

resource "dbtcloud_bigquery_credential" "development" {
  project_id = dbtcloud_project.this.id
  dataset    = "${var.schema_prefix}_${var.schema_development}"
  num_threads = 4
}

resource "dbtcloud_bigquery_credential" "staging" {
  project_id = dbtcloud_project.this.id
  dataset    = "${var.schema_prefix}_${var.schema_staging}"
  num_threads = 16
}

resource "dbtcloud_bigquery_credential" "production" {
  project_id = dbtcloud_project.this.id
  dataset    = "${var.schema_prefix}_${var.schema_production}"
  num_threads = 16
}

# ─── Environments ─────────────────────────────────────────────────────────────

resource "dbtcloud_environment" "development" {
  project_id        = dbtcloud_project.this.id
  name              = "Development"
  dbt_version       = var.dbt_version
  type              = "development"
  credential_id     = dbtcloud_bigquery_credential.development.credential_id
  connection_id     = dbtcloud_global_connection.bigquery.id
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
  credential_id     = dbtcloud_bigquery_credential.staging.credential_id
  connection_id     = dbtcloud_global_connection.bigquery.id
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
  credential_id     = dbtcloud_bigquery_credential.production.credential_id
  connection_id     = dbtcloud_global_connection.bigquery.id
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

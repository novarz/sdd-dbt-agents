# ─── Project ──────────────────────────────────────────────────────────────────

resource "dbtcloud_project" "this" {
  name = var.project_name
}

# ─── Repository ───────────────────────────────────────────────────────────────

resource "dbtcloud_repository" "this" {
  project_id             = dbtcloud_project.this.id
  remote_url             = var.git_remote_url
  git_clone_strategy     = var.git_clone_strategy
  github_installation_id = var.github_installation_id
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
  project_id    = dbtcloud_project.this.id
  name          = "Development"
  dbt_version   = var.dbt_version
  type          = "development"
  credential_id = dbtcloud_snowflake_credential.development.credential_id
  connection_id = dbtcloud_global_connection.snowflake.id

  depends_on = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "staging" {
  project_id      = dbtcloud_project.this.id
  name            = "Staging"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "staging"
  credential_id   = dbtcloud_snowflake_credential.staging.credential_id
  connection_id   = dbtcloud_global_connection.snowflake.id

  depends_on = [dbtcloud_repository.this]
}

resource "dbtcloud_environment" "production" {
  project_id      = dbtcloud_project.this.id
  name            = "Production"
  dbt_version     = var.dbt_version
  type            = "deployment"
  deployment_type = "production"
  credential_id   = dbtcloud_snowflake_credential.production.credential_id
  connection_id   = dbtcloud_global_connection.snowflake.id

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

resource "dbtcloud_semantic_layer_configuration" "this" {
  project_id     = dbtcloud_project.this.id
  environment_id = dbtcloud_environment.production.environment_id
}

resource "dbtcloud_snowflake_semantic_layer_credential" "this" {
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
  project_id                   = dbtcloud_project.this.id
  semantic_layer_credential_id = dbtcloud_snowflake_semantic_layer_credential.this.id
  service_token_id             = dbtcloud_service_token.semantic_layer.id
}

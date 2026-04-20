# ─── dbt Platform ───────────────────────────────────────────────────────────────

variable "dbt_account_id" {
  description = "dbt Platform Account ID"
  type        = number
}

variable "dbt_host_url" {
  description = "dbt Platform host URL (e.g. https://emea.dbt.com/api)"
  type        = string
}

variable "dbt_token" {
  description = "dbt Platform Service Token with Account Admin permissions"
  type        = string
  sensitive   = true
}

# ─── Project ──────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Name of the dbt Platform project"
  type        = string
}

variable "dbt_version" {
  description = "dbt version for environments (use 'versionless' for latest)"
  type        = string
  default     = "versionless"
}

# ─── Git repository ───────────────────────────────────────────────────────────

variable "git_branch" {
  description = "Git branch to use for all environments"
  type        = string
  default     = "main"
}

variable "git_remote_url" {
  description = "SSH URL of the git repository (e.g. git@github.com:org/repo.git)"
  type        = string
}

variable "git_clone_strategy" {
  description = "Clone strategy: github_app | deploy_key | azure_active_directory_app"
  type        = string
  default     = "github_app"
}

variable "github_installation_id" {
  description = "GitHub App installation ID. If null, auto-discovered via GITHUB_TOKEN + GITHUB_ORG env vars."
  type        = number
  default     = null
}

# ─── Databricks connection ───────────────────────────────────────────────────

variable "databricks_host" {
  description = "Databricks workspace URL (e.g. https://dbc-a1b2c3d4-e5f6.cloud.databricks.com)"
  type        = string
}

variable "databricks_http_path" {
  description = "HTTP path for SQL warehouse or cluster (e.g. /sql/1.0/warehouses/abc123)"
  type        = string
}

variable "databricks_token" {
  description = "Databricks personal access token"
  type        = string
  sensitive   = true
}

variable "databricks_catalog" {
  description = "Unity Catalog name (e.g. analytics)"
  type        = string
}

# ─── Environments / schemas ───────────────────────────────────────────────────

variable "schema_prefix" {
  description = "Prefix for all Databricks schemas (e.g. dbt_myproject)"
  type        = string
}

variable "schema_development" {
  description = "Schema suffix for the Development environment"
  type        = string
  default     = "dev"
}

variable "schema_staging" {
  description = "Schema suffix for the Staging environment"
  type        = string
  default     = "staging"
}

variable "schema_production" {
  description = "Schema suffix for the Production environment"
  type        = string
  default     = "prod"
}

# ─── Preflight ────────────────────────────────────────────────────────────────

variable "skip_preflight_validation" {
  description = "Skip credential validation before applying."
  type        = bool
  default     = false
}

# ─── Semantic Layer ───────────────────────────────────────────────────────────

variable "enable_semantic_layer" {
  description = "Set to true only after a successful production job run exists"
  type        = bool
  default     = false
}

# ─── Environment Variables (source overrides per environment) ─────────────

variable "source_database" {
  description = "Default source database/catalog for all environments"
  type        = string
  default     = ""
}

variable "source_schema_prefix" {
  description = "Default source schema prefix for all environments"
  type        = string
  default     = ""
}

variable "source_database_production" {
  description = "Source database override for production (empty = use default)"
  type        = string
  default     = ""
}

variable "source_schema_prefix_production" {
  description = "Source schema prefix override for production (empty = use default)"
  type        = string
  default     = ""
}

# ─── Jobs ─────────────────────────────────────────────────────────────────────

variable "daily_job_schedule_hours" {
  description = "UTC hours at which the daily job runs (list)"
  type        = list(number)
  default     = [6]
}

# ─── Webhook (dbt-ops alerting) ──────────────────────────────────────────────

variable "webhook_endpoint_url" {
  description = "HTTPS endpoint for dbt-ops webhook alerts (empty = disabled)"
  type        = string
  default     = ""
}

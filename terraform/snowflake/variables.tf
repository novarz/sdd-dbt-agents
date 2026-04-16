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

# ─── Snowflake connection ─────────────────────────────────────────────────────

variable "snowflake_account" {
  description = "Snowflake account identifier (e.g. zna84829)"
  type        = string
}

variable "snowflake_database" {
  description = "Snowflake database"
  type        = string
}

variable "snowflake_warehouse" {
  description = "Snowflake virtual warehouse"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake user"
  type        = string
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "snowflake_role" {
  description = "Snowflake role (leave empty to use default)"
  type        = string
  default     = ""
}

# ─── Environments / schemas ───────────────────────────────────────────────────

variable "schema_prefix" {
  description = "Prefix for all Snowflake schemas (e.g. dbt_myproject)"
  type        = string
}

variable "schema_development" {
  description = "Snowflake schema suffix for the Development environment"
  type        = string
  default     = "dev"
}

variable "schema_staging" {
  description = "Snowflake schema suffix for the Staging environment"
  type        = string
  default     = "staging"
}

variable "schema_production" {
  description = "Snowflake schema suffix for the Production environment"
  type        = string
  default     = "prod"
}

# ─── Preflight ────────────────────────────────────────────────────────────────

variable "skip_preflight_validation" {
  description = "Skip credential validation before applying. Use if snow/snowsql is not available or validation fails for network reasons."
  type        = bool
  default     = false
}

# ─── Semantic Layer ───────────────────────────────────────────────────────────

variable "enable_semantic_layer" {
  description = "Set to true only after a successful production job run exists"
  type        = bool
  default     = false
}

# ─── Jobs ─────────────────────────────────────────────────────────────────────

variable "daily_job_schedule_hours" {
  description = "UTC hours at which the daily job runs (list)"
  type        = list(number)
  default     = [6]
}

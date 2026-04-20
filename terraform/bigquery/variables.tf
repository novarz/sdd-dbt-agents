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

# ─── BigQuery connection ─────────────────────────────────────────────────────

variable "gcp_project_id" {
  description = "GCP project ID where BigQuery datasets live"
  type        = string
}

variable "gcp_location" {
  description = "BigQuery dataset location (e.g. US, EU, us-central1)"
  type        = string
  default     = "US"
}

variable "bigquery_timeout_seconds" {
  description = "Timeout in seconds for BigQuery queries"
  type        = number
  default     = 300
}

variable "bigquery_retries" {
  description = "Number of retries for BigQuery queries"
  type        = number
  default     = 1
}

variable "bigquery_private_key_id" {
  description = "GCP service account private key ID"
  type        = string
  sensitive   = true
}

variable "bigquery_private_key" {
  description = "GCP service account private key (PEM format)"
  type        = string
  sensitive   = true
}

variable "bigquery_client_email" {
  description = "GCP service account email"
  type        = string
}

variable "bigquery_client_id" {
  description = "GCP service account client ID"
  type        = string
}

variable "bigquery_auth_uri" {
  description = "GCP auth URI"
  type        = string
  default     = "https://accounts.google.com/o/oauth2/auth"
}

variable "bigquery_token_uri" {
  description = "GCP token URI"
  type        = string
  default     = "https://oauth2.googleapis.com/token"
}

variable "bigquery_auth_provider_x509_cert_url" {
  description = "GCP auth provider x509 cert URL"
  type        = string
  default     = "https://www.googleapis.com/oauth2/v1/certs"
}

variable "bigquery_client_x509_cert_url" {
  description = "GCP client x509 cert URL"
  type        = string
}

# ─── Environments / datasets ─────────────────────────────────────────────────

variable "schema_prefix" {
  description = "Prefix for all BigQuery datasets (e.g. dbt_myproject)"
  type        = string
}

variable "schema_development" {
  description = "BigQuery dataset suffix for the Development environment"
  type        = string
  default     = "dev"
}

variable "schema_staging" {
  description = "BigQuery dataset suffix for the Staging environment"
  type        = string
  default     = "staging"
}

variable "schema_production" {
  description = "BigQuery dataset suffix for the Production environment"
  type        = string
  default     = "prod"
}

# ─── Preflight ────────────────────────────────────────────────────────────────

variable "skip_preflight_validation" {
  description = "Skip credential validation before applying. Use if bq CLI is not available."
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
  description = "Default source database/project for all environments"
  type        = string
  default     = ""
}

variable "source_schema_prefix" {
  description = "Default source schema/dataset prefix for all environments"
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

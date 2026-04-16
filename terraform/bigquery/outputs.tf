# ─── Semantic Layer outputs ───────────────────────────────────────────────────

output "semantic_layer_token" {
  description = "Service token for the Semantic Layer (only shown on first apply)"
  value       = dbtcloud_service_token.semantic_layer.token_string
  sensitive   = true
}

output "semantic_layer_token_uid" {
  description = "UID of the Semantic Layer service token"
  value       = dbtcloud_service_token.semantic_layer.uid
}

output "semantic_layer_enabled" {
  description = "Whether the Semantic Layer configuration has been applied"
  value       = var.enable_semantic_layer
}

output "project_id" {
  description = "dbt Platform project ID"
  value       = dbtcloud_project.this.id
}

output "production_environment_id" {
  description = "dbt Platform Production environment ID"
  value       = dbtcloud_environment.production.environment_id
}

output "staging_environment_id" {
  description = "dbt Platform Staging environment ID"
  value       = dbtcloud_environment.staging.environment_id
}

output "development_environment_id" {
  description = "dbt Platform Development environment ID"
  value       = dbtcloud_environment.development.environment_id
}

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

output "project_id" {
  description = "dbt Cloud project ID"
  value       = dbtcloud_project.this.id
}

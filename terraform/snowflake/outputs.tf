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

# ─── MCP outputs ──────────────────────────────────────────────────────────────

output "mcp_token" {
  description = "Service token for the dbt MCP server (metadata + semantic layer + job admin + developer)"
  value       = dbtcloud_service_token.mcp.token_string
  sensitive   = true
}

output "mcp_token_uid" {
  description = "UID of the MCP service token"
  value       = dbtcloud_service_token.mcp.uid
}

# ─── Webhook outputs ─────────────────────────────────────────────────────────

output "webhook_hmac_secret" {
  description = "HMAC secret for verifying webhook payloads (only shown on first apply)"
  value       = var.webhook_endpoint_url != "" ? dbtcloud_webhook.ops_alert[0].hmac_secret : ""
  sensitive   = true
}

output "webhook_id" {
  description = "ID of the dbt-ops webhook"
  value       = var.webhook_endpoint_url != "" ? dbtcloud_webhook.ops_alert[0].webhook_id : ""
}

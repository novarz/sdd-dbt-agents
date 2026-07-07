terraform {
  # Uncomment for remote state (recommended for team use):
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "dbt-platform/snowflake/terraform.tfstate"
  #   region = "eu-west-1"
  # }
  # backend "gcs" {
  #   bucket = "my-terraform-state"
  #   prefix = "dbt-platform/snowflake"
  # }

  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "~> 1.12"  # >=1.12 required for Fusion release-track names (fusion-stable, etc.)
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "dbtcloud" {
  token      = var.dbt_token
  account_id = var.dbt_account_id
  host_url   = var.dbt_host_url
}

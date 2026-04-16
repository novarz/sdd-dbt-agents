terraform {
  # Uncomment for remote state (recommended for team use):
  # backend "gcs" {
  #   bucket = "my-terraform-state"
  #   prefix = "dbt-platform/bigquery"
  # }
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "dbt-platform/bigquery/terraform.tfstate"
  #   region = "eu-west-1"
  # }

  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "~> 1.8.2"
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

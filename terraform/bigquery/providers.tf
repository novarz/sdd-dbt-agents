terraform {
  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "~> 1.8.2"
    }
  }
}

provider "dbtcloud" {
  token      = var.dbt_token
  account_id = var.dbt_account_id
  host_url   = var.dbt_host_url
}

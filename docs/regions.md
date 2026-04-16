# dbt Platform regions and host URLs

| Region         | Cloud  | `dbt_host_url`                    |
|----------------|--------|-----------------------------------|
| US multi-tenant | AWS   | `https://cloud.getdbt.com/api`    |
| EMEA           | AWS    | `https://emea.dbt.com/api`        |
| APAC           | AWS    | `https://au.dbt.com/api`          |
| EMEA           | GCP    | `https://emea.dbt.com/api`        |

> **Note:** The Terraform provider appends `/v2/` to the `host_url`.
> Always include `/api` at the end of the URL or requests will hit S3 and fail with a 400 error.

To find your account prefix and region, log in and check the URL in your browser:
`https://<ACCOUNT_PREFIX>.<REGION>.dbt.com`

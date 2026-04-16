# How to find the GitHub App Installation ID

The `github_installation_id` links your dbt Platform account to a GitHub organization via the GitHub App.

## Option 1 — via dbt Platform API (recommended)

You need an existing project in dbt Platform with the GitHub App already connected.
Then run:

```bash
curl -s \
  -H "Authorization: Token <DBT_TOKEN>" \
  "https://emea.dbt.com/api/v3/accounts/<ACCOUNT_ID>/projects/<PROJECT_ID>/repositories/" \
  | python3 -m json.tool \
  | grep -E "github_installation_id|git_clone_strategy"
```

Look for the entry with `"git_clone_strategy": "github_app"` — that `github_installation_id` is the value you need.

## Option 2 — via GitHub

Go to: `https://github.com/organizations/<YOUR_ORG>/settings/installations`

Click on the dbt Platform App installation → the ID is in the URL:
`https://github.com/organizations/MY_ORG/settings/installations/103071669`
                                                                  ^^^^^^^^^

## Notes

- The installation ID is **per GitHub org**, not per repo or dbt Platform project.
- If all your repos are in the same GitHub org, the ID is always the same.

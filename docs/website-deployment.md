# CaveRace website deployment

The [Check and deploy CaveRace website](../.github/workflows/deploy-website.yml)
workflow publishes the existing static `website/` directory. No game build,
Hugo, npm dependencies, or generated site step is needed.

Changes to `website/**`, the checker, or the workflow on `main` trigger checks
and production publication. Pull requests run checks only. Select **Run workflow**
on `main` to redeploy. Runs from other branches cannot deploy.

## Confirmed Azure target

| Setting | Value |
| --- | --- |
| Subscription | `e42fceff-ea17-403e-96cd-3337df3043b1` |
| Tenant | `9be79373-29bb-4b8a-a999-495ad397f5ae` |
| Storage account | `caverace` |
| Front Door resource group | `NavaTron` |
| Front Door profile | `navatron` (shared with the studio website) |
| Front Door endpoint | `caverace` |
| Endpoint hostname | `caverace-fthrcjdte0hvaja5.z01.azurefd.net` |
| Cache purge domain | `caverace.com` |

These non-secret target identifiers are explicit in the workflow. It uploads only
to `caverace/$web` and purges the `caverace` endpoint. The NavaTron website's
storage account and endpoint are separate.

## One-time identity setup

In a checkout of this branch, sign in with Azure CLI and GitHub CLI:

```bash
az login
gh auth login
bash scripts/setup_website_azure.sh
```

The signed-in Azure user needs permission to create managed identities, federated
credentials, custom roles, and role assignments. GitHub access must permit setting
repository Actions variables.

The script resolves the actual storage resource group, checks the target endpoint,
creates or reuses `github-caverace-website` in `NavaTron`, and creates a federated
credential with:

- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`
- Subject: `repo:NavaTron/CaveRace:ref:refs/heads/main`

It grants **Storage Blob Data Contributor** only on CaveRace's `$web` container
and the [custom cache-purger role](../.github/azure-front-door-purge-role.json)
only on the CaveRace Front Door endpoint. The role allows endpoint read and purge,
with no other actions.

Finally, it sets the single required repository Actions variable,
`AZURE_CLIENT_ID`, to the managed identity's client ID. No storage account keys or
client secrets are used. The script can be rerun and preserves existing matching
role assignments.

The script does not upload content or alter domains, routes, hosting settings,
or the NavaTron site's identity. Static website hosting must already use
`index.html` and `404.html`; the caverace.com Front Door route must point to
the CaveRace storage origin. Azure access setup has not been executed by Codex.

## Validation and publication

Run the dependency-free checker locally:

```bash
python3 scripts/check_website.py website
```

It checks required pages and machine-readable outputs, sitemap XML, JSON-LD,
and local HTML asset/link targets. GitHub retains the verified website artifact
for 14 days.

Production uses OpenID Connect. Deployments run one at a time, skip superseded
commits, upload assets before HTML, and use five-minute browser cache headers.
Uploads preserve existing blobs absent from the source; removal requires an
explicit blob deletion or redirect.

After upload, the workflow purges the configured Front Door domains and waits
for `https://caverace.com/` to match the uploaded homepage. A failure prevents
the workflow from reporting success.

For recovery, correct configuration and rerun the current main deployment.
To roll back content, revert the change on main; the workflow publishes that
revert.

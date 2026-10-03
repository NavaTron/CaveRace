# CaveRace website deployment

The [Check and deploy CaveRace website](../.github/workflows/deploy-website.yml)
workflow publishes the existing static `website/` directory. No game build,
Hugo, npm dependencies, or generated site step is needed.

Changes to `website/**`, the checker, or the workflow on `main` trigger checks
and production publication. Pull requests run checks only. Select **Run workflow**
on `main` to redeploy. Runs from other branches cannot deploy.

## Configure Azure access before the first deployment

Use the same Azure Storage static website and Azure Front Door pattern as
NavaTron/Website, with the resources that actually serve caverace.com.
Do not reuse NavaTron's storage account value unless it is the intended CaveRace
origin: deployment overwrites matching files in the target `$web` container.

Create or select an Azure managed identity or application, then add a GitHub
federated credential with:

- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`
- Subject: `repo:NavaTron/CaveRace:ref:refs/heads/main`

Grant **Storage Blob Data Contributor** at the CaveRace `$web` container scope.
For Front Door, grant endpoint read and purge permissions at the intended endpoint
scope, using the same custom role pattern as NavaTron/Website:
`Microsoft.Cdn/profiles/afdendpoints/read` and
`Microsoft.Cdn/profiles/afdendpoints/purge/action`.

Configure repository **Settings → Secrets and variables → Actions → Variables**:

| Variable | Required value |
| --- | --- |
| `AZURE_CLIENT_ID` | Deployment identity's client ID |
| `AZURE_TENANT_ID` | Identity's tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |
| `AZURE_STORAGE_ACCOUNT` | Storage account serving CaveRace |
| `AZURE_FRONT_DOOR_RESOURCE_GROUP` | Front Door resource group |
| `AZURE_FRONT_DOOR_PROFILE` | Front Door profile name |
| `AZURE_FRONT_DOOR_ENDPOINT` | Front Door endpoint name |
| `AZURE_FRONT_DOOR_DOMAINS` | Space-separated domains on that endpoint to purge; include `caverace.com` |

These are identifiers, not credentials. No storage keys or client secrets are
required. This repository change does not create Azure resources, grant roles,
or configure repository variables.

Enable static website hosting on the target storage account, with `index.html`
as the index document and `404.html` as the error document. Confirm the Front Door
origin, custom domain, and TLS configuration already serve that account.

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

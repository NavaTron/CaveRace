#!/usr/bin/env bash
# Run once with Azure CLI and GitHub CLI signed in.
# Creates deployment identity/access and sets AZURE_CLIENT_ID; does not deploy.
set -euo pipefail

repo='NavaTron/CaveRace'
subscription='e42fceff-ea17-403e-96cd-3337df3043b1'
tenant='9be79373-29bb-4b8a-a999-495ad397f5ae'
resource_group='NavaTron'
identity_name='github-caverace-website'
storage_account='caverace'
profile='navatron'
endpoint='caverace'
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
role_file="${script_dir}/../.github/azure-front-door-purge-role.json"

command -v az >/dev/null || { echo 'Install Azure CLI first.' >&2; exit 1; }
command -v gh >/dev/null || { echo 'Install GitHub CLI first.' >&2; exit 1; }
test -s "$role_file"
gh auth status --hostname github.com
gh repo view "$repo" --json nameWithOwner --jq '.nameWithOwner' >/dev/null
actual_tenant=$(az account show --subscription "$subscription" --query tenantId -o tsv)
[[ "$actual_tenant" == "$tenant" ]] || { echo 'Azure tenant does not match the deployment target.' >&2; exit 1; }

# Resolve the storage account's actual resource group instead of assuming it.
storage_id=$(az storage account list --subscription "$subscription" \
  --query "[?name=='${storage_account}'].id | [0]" -o tsv)
[[ -n "$storage_id" && "$storage_id" != 'None' ]] || { echo 'CaveRace storage account was not found.' >&2; exit 1; }
endpoint_id=$(az afd endpoint show --subscription "$subscription" \
  --resource-group "$resource_group" --profile-name "$profile" \
  --endpoint-name "$endpoint" --query id -o tsv)
[[ -n "$endpoint_id" && "$endpoint_id" != 'None' ]] || { echo 'CaveRace Front Door endpoint was not found.' >&2; exit 1; }
location=$(az group show --subscription "$subscription" --name "$resource_group" --query location -o tsv)

if ! az identity show --subscription "$subscription" --resource-group "$resource_group" \
  --name "$identity_name" --output none 2>/dev/null; then
  az identity create --subscription "$subscription" --resource-group "$resource_group" \
    --name "$identity_name" --location "$location" --output none
fi
client_id=$(az identity show --subscription "$subscription" --resource-group "$resource_group" \
  --name "$identity_name" --query clientId -o tsv)
principal_id=$(az identity show --subscription "$subscription" --resource-group "$resource_group" \
  --name "$identity_name" --query principalId -o tsv)

az identity federated-credential create --subscription "$subscription" \
  --resource-group "$resource_group" --identity-name "$identity_name" --name github-main \
  --issuer 'https://token.actions.githubusercontent.com' \
  --subject 'repo:NavaTron/CaveRace:ref:refs/heads/main' \
  --audiences 'api://AzureADTokenExchange' --output none

role_id=$(az role definition list --subscription "$subscription" \
  --name 'CaveRace Website Front Door Cache Purger' --query '[0].name' -o tsv)
if [[ -z "$role_id" || "$role_id" == 'None' ]]; then
  role_id=$(az role definition create --subscription "$subscription" \
    --role-definition "$role_file" --query name -o tsv)
fi

assign_role() {
  local role="$1" scope="$2"
  local count
  count=$(az role assignment list --subscription "$subscription" --scope "$scope" \
    --query "length([?principalId=='${principal_id}' && ends_with(roleDefinitionId, '/${role}') && scope=='${scope}'])" -o tsv)
  if [[ "$count" == '0' ]]; then
    az role assignment create --subscription "$subscription" \
      --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
      --role "$role" --scope "$scope" --output none
  fi
}
# Built-in Storage Blob Data Contributor, scoped only to this site's container.
assign_role 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' "${storage_id}/blobServices/default/containers/\$web"
assign_role "$role_id" "$endpoint_id"
gh variable set AZURE_CLIENT_ID --repo "$repo" --body "$client_id"

echo "Configured $identity_name for $repo."
echo 'Azure role and federation changes can take a few minutes to propagate.'
echo 'Merge the deployment PR, then inspect the first GitHub Actions deployment.'

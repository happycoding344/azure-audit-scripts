#!/usr/bin/env bash
# =============================================================================
#  Azure Cost Audit - remove access
#  Deletes the role assignments and the "cost-audit-naveenchandra" app.
#  Run in https://shell.azure.com (Bash):   bash revoke-access.sh
# =============================================================================
set -euo pipefail
APP_NAME="cost-audit-naveenchandra"

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
[ -z "$APP_ID" ] && { echo "Nothing to remove - $APP_NAME not found."; exit 0; }

SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv 2>/dev/null || true)
if [ -n "$SP_OBJECT_ID" ]; then
  for id in $(az role assignment list --assignee "$SP_OBJECT_ID" --all --query "[].id" -o tsv); do
    az role assignment delete --ids "$id" && echo "    removed role assignment"
  done
fi
az ad app delete --id "$APP_ID"
echo "==> Removed $APP_NAME ($APP_ID). Access is fully revoked."

#!/usr/bin/env bash
# =============================================================================
#  Azure Cost Audit - grant read-only access
#  audit.naveenchandra.co.in
#
#  WHAT THIS DOES
#    1. Creates an app registration "cost-audit-naveenchandra"
#    2. Gives it READ-ONLY roles on the subscriptions you choose:
#         - Reader                  (see resources, metrics, Advisor)
#         - Cost Management Reader  (see billing data)
#    3. Creates one client secret that EXPIRES IN 30 DAYS
#    4. Prints the 3 values to send back (use a one-time secret link)
#
#  It cannot create, change or delete anything in your environment.
#  Remove it any time with revoke-access.sh.
#
#  HOW TO RUN
#    Open https://shell.azure.com (Bash), then:
#      bash grant-access.sh                 # all enabled subscriptions
#      bash grant-access.sh <sub-id> [...]  # only these subscriptions
#
#  You need Owner or User Access Administrator on the subscriptions,
#  and permission to create app registrations in Entra ID.
# =============================================================================
set -euo pipefail

APP_NAME="cost-audit-naveenchandra"
DAYS_VALID="${DAYS_VALID:-30}"   # Monthly Watch clients: DAYS_VALID=365 bash grant-access.sh

echo "==> Signed in as: $(az account show --query user.name -o tsv)"
TENANT_ID=$(az account show --query tenantId -o tsv)

if [ "$#" -gt 0 ]; then
  SUBS=("$@")
else
  mapfile -t SUBS < <(az account list --query "[?state=='Enabled' && tenantId=='$TENANT_ID'].id" -o tsv)
fi
[ "${#SUBS[@]}" -eq 0 ] && { echo "No subscriptions found."; exit 1; }

echo "==> Subscriptions in scope:"
for s in "${SUBS[@]}"; do
  echo "    - $s  ($(az account show -s "$s" --query name -o tsv))"
done
read -r -p "Grant READ-ONLY access to these? [y/N] " ok
[[ "$ok" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

# --- app + service principal (reuse if it already exists) -------------------
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "==> Created app registration $APP_NAME"
fi
az ad sp show --id "$APP_ID" >/dev/null 2>&1 || az ad sp create --id "$APP_ID" >/dev/null
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

# Entra ID can take a few seconds to replicate a new service principal
for i in 1 2 3 4 5 6; do
  az role assignment list --assignee "$SP_OBJECT_ID" --all >/dev/null 2>&1 && break || sleep 5
done

# --- read-only role assignments ------------------------------------------------
for s in "${SUBS[@]}"; do
  for role in "Reader" "Cost Management Reader"; do
    for i in 1 2 3 4 5 6; do
      if az role assignment create --assignee-object-id "$SP_OBJECT_ID" \
           --assignee-principal-type ServicePrincipal \
           --role "$role" --scope "/subscriptions/$s" >/dev/null 2>&1; then
        echo "    $role -> $s"; break
      fi
      sleep 10
      [ "$i" -eq 6 ] && echo "    WARNING: could not assign $role on $s"
    done
  done
done

# --- short-lived secret --------------------------------------------------------
END_DATE=$(date -u -d "+${DAYS_VALID} days" +%Y-%m-%dT%H:%M:%SZ)
SECRET=$(az ad app credential reset --id "$APP_ID" --display-name "cost-audit" \
          --end-date "$END_DATE" --query password -o tsv 2>/dev/null)

cat <<EOF

=============================================================================
 Done. Please send these three values via a one-time secret link
 (for example onetimesecret.com), not in plain email:

   AZURE_TENANT_ID=$TENANT_ID
   AZURE_CLIENT_ID=$APP_ID
   AZURE_CLIENT_SECRET=$SECRET

 Secret expires: $END_DATE (automatically, no action needed)
 Subscriptions:  ${SUBS[*]}

 To remove access early:  bash revoke-access.sh
=============================================================================
EOF

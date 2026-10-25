# Azure Cost Audit: access scripts

These are the two scripts used to grant and remove read-only access for the [Azure Cost Audit](https://audit.naveenchandra.co.in) by Naveen Chandra.

**This repository is the canonical copy.** The audit site links to a specific commit, so the file you review here is byte-for-byte the file you run. The copies on audit.naveenchandra.co.in are mirrors.

| Script | What it does |
|---|---|
| [`grant-access.sh`](grant-access.sh) | Creates one app registration, `cost-audit-naveenchandra`, and gives it the **Reader** and **Cost Management Reader** roles on the subscriptions you confirm. It creates one client secret that expires after 30 days, then prints the three values to send back. It asks before changing anything. |
| [`revoke-access.sh`](revoke-access.sh) | Removes the app's role assignments and deletes the app registration. |

Neither script can create, change or delete resources in your environment. Both roles are read-only.

## Run

Open [Azure Cloud Shell](https://shell.azure.com) (Bash). Replace `<commit>` with the commit shown on the audit site:

```bash
curl -sLO https://raw.githubusercontent.com/happycoding344/azure-audit-scripts/<commit>/grant-access.sh
bash grant-access.sh                 # all enabled subscriptions in the tenant
bash grant-access.sh <sub-id> [...]  # only these subscriptions
```

To remove access early:

```bash
curl -sLO https://raw.githubusercontent.com/happycoding344/azure-audit-scripts/<commit>/revoke-access.sh
bash revoke-access.sh
```

You need Owner or User Access Administrator on the subscriptions, plus permission to create app registrations in Entra ID.

## Verify

```bash
sha256sum grant-access.sh revoke-access.sh
```

```
1bdece6ebd774bf4a89882a7ceef12f0545531b4e579f370c50f822c587512f1  grant-access.sh
a75b36679794500f2f4144fb6694f8e6478b68dd70248e4dbf403d26cf8aec19  revoke-access.sh
```

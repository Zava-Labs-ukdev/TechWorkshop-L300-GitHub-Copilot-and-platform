# Deploy Workflow — Setup Guide

## Required GitHub Secrets

| Name | Where to set | Description |
|---|---|---|
| `AZURE_CREDENTIALS` | Settings → Secrets → Actions | Service principal JSON (see below) |

## Required GitHub Variables

| Name | Where to set | Value |
|---|---|---|
| `ACR_NAME` | Settings → Variables → Actions | `acrzavastoredevv1` |
| `AZURE_WEBAPP_NAME` | Settings → Variables → Actions | `app-zavastore-dev-v1` |
| `AZURE_RESOURCE_GROUP` | Settings → Variables → Actions | `rg-dev-v1` |

---

## Creating the Service Principal

Run the following command once to create a service principal with the permissions needed to push images and update the App Service:

```bash
az ad sp create-for-rbac \
  --name "sp-zavastore-deploy" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-dev-v1 \
  --sdk-auth
```

Copy the entire JSON output and add it as the `AZURE_CREDENTIALS` secret in GitHub.

> **Note:** The `AcrPush` role is covered by `contributor` on the resource group. The App Service pulls images using its own managed identity (no extra credentials needed at runtime).

---

## How It Works

1. On every push to `main`, the workflow triggers.
2. It logs into Azure using the service principal.
3. `az acr build` sends the source code to ACR for a cloud-side Docker build — **no local Docker required**.
4. The new image is tagged with the commit SHA and `latest`.
5. `az webapp config container set` updates the App Service to use the new image tag.

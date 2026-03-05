# ZavaStorefront — Azure Infrastructure

This folder contains all Bicep templates and AZD configuration for provisioning the ZavaStorefront dev environment on Azure.

## Resources Provisioned

| Resource | Module | Notes |
|---|---|---|
| Log Analytics Workspace | `modules/logAnalytics.bicep` | Feeds Application Insights |
| Application Insights | `modules/appInsights.bicep` | Workspace-based; linked to Log Analytics |
| Azure Container Registry (Basic) | `modules/acr.bicep` | Admin disabled; RBAC-only pulls |
| App Service Plan (Linux B1) | `modules/appService.bicep` | Linux; dev SKU |
| Web App for Containers | `modules/appService.bicep` | System-assigned managed identity |
| AcrPull Role Assignment | `modules/roleAssignment.bicep` | Grants Web App identity AcrPull on ACR |
| Azure AI Foundry Hub | `modules/foundry.bicep` | GPT-4o + Phi-4 model deployments |

All resources are deployed into a single resource group in **swedencentral**.

---

## RBAC: Passwordless ACR Integration

The App Service pulls container images from ACR using **Azure managed identity** — no passwords or secrets are stored anywhere.

**How it works:**
1. The Web App has a **system-assigned managed identity** enabled (configured in `modules/appService.bicep`).
2. The `modules/roleAssignment.bicep` module assigns the built-in **AcrPull** role (`7f951dda-4ed3-4680-a7ca-43fe172d538d`) to that identity, scoped to the ACR resource.
3. The App Service site config sets `acrUseManagedIdentityCreds: true`, instructing the platform to use the managed identity for image pulls.
4. The `DOCKER_REGISTRY_SERVER_URL` app setting points to the ACR login server.

No service principal credentials, no admin passwords, no secrets in CI/CD.

---

## Developer Setup (No Local Docker Required)

You do not need Docker installed locally. Container images are built and pushed in the cloud.

### Prerequisites
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- .NET 6 SDK (for local development only)

### 1. Authenticate
```bash
az login
azd auth login
```

### 2. Provision infrastructure
```bash
azd provision
```

When prompted:
- **Environment name:** e.g. `dev`
- **Location:** `swedencentral`

This creates the resource group and all Azure resources.

### 3. Build and push the container image (cloud build)
```bash
# No local Docker needed — az acr build runs the build on Azure
ACR_NAME=$(azd env get-values | grep AZURE_ACR_NAME | cut -d= -f2)

az acr build \
  --registry $ACR_NAME \
  --image zava-storefront:latest \
  .
```

### 4. Deploy the application
```bash
azd deploy
```

This updates the Web App to use the newly pushed image.

### 5. All-in-one (provision + deploy)
```bash
azd up
```

---

## Environment Variables (set by AZD)

| Variable | Description |
|---|---|
| `AZURE_ENV_NAME` | AZD environment name (e.g. `dev`) |
| `AZURE_LOCATION` | Azure region (`swedencentral`) |
| `AZURE_SUBSCRIPTION_ID` | Target subscription |

---

## Cost Notes (Dev)

| Resource | SKU | Approximate monthly cost |
|---|---|---|
| App Service Plan | B1 Linux | ~$13 |
| Container Registry | Basic | ~$5 |
| Log Analytics | Pay-as-you-go | ~$0–2 (low ingestion) |
| Application Insights | Pay-as-you-go | ~$0–2 |
| AI Foundry | Consumption | Pay-per-token |

> Tear down all resources when not in use: `azd down`

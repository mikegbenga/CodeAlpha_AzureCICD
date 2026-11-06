# Setup guide — Task 1 (Azure CI/CD)

Plan on about 30 minutes. Everything fits on the cheapest tiers: ACR Basic and App Service B1 (or F1 for a demo).

## 0. Prerequisites
- An Azure subscription ([free account](https://azure.microsoft.com/free) works)
- An Azure DevOps organization: https://dev.azure.com (free for up to 5 users)
- Azure CLI 2.60+ and Terraform 1.6+ (or just the Azure CLI)
- This repo pushed to GitHub as **`CodeAlpha_AzureCICD`**

> **Free-tier parallelism:** new Azure DevOps orgs need to request free Microsoft-hosted parallel jobs
> (https://aka.ms/azpipelines-parallelism-request). Approval can take 1–3 business days, so request it on day one.
> While you wait, a self-hosted agent works too.

## 1. Provision Azure resources

**Terraform**
```bash
az login
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # put in your subscription_id, alert_email, and unique names
terraform init
terraform apply
```
The ACR and Web App names must be globally unique. Change the `mga` suffix if a name is already taken.

**…or the Azure CLI**
```bash
az login
./scripts/bootstrap-azure.sh     # override with env vars: RG=… ACR=… APP=… ./scripts/bootstrap-azure.sh
```

> The Web App starts on `:latest`. Terraform doesn't build images, so on the first run the app shows an
> image-pull error until the pipeline pushes the first image. That's expected. (The CLI script seeds an image with `az acr build`.)

## 2. Create service connections (Azure DevOps → Project settings → Service connections)

| Name | Type | Settings |
|---|---|---|
| `sc-acr-codealpha` | Docker Registry → **Azure Container Registry** | Subscription + registry `acrcodealphamga` |
| `sc-azure-codealpha` | Azure Resource Manager → **Workload identity federation (automatic)** | Scope: resource group `rg-codealpha-cicd` |

Tick **"Grant access permission to all pipelines"**, or approve each connection on the first run.

## 3. Create the environment
*Pipelines → Environments → New environment* → name it **`codealpha-production`** (None resource).
Optional: *Approvals and checks → Approvals* adds a manual gate before production.

## 4. Create the pipeline
*Pipelines → New pipeline → GitHub → select the repo → Existing Azure Pipelines YAML file → `/azure-pipelines.yml` → Run.*

If your names differ from the defaults, edit the `variables:` block first:

```yaml
dockerRegistryServiceConnection: 'sc-acr-codealpha'
azureSubscription: 'sc-azure-codealpha'
acrLoginServer: 'acrcodealphamga.azurecr.io'
webAppName: 'app-codealpha-mga'
resourceGroup: 'rg-codealpha-cicd'
```

## 5. Verify
- All 3 stages are green, and the *Tests* tab shows 6 passed
- `https://app-codealpha-mga.azurewebsites.net` shows the running Build ID
- `az acr repository show-tags -n acrcodealphamga --repository codealpha-webapp -o table`

## 6. Prove the rollback works (good for the demo video)
1. Deploy a good build first, so there's an image to roll back to.
2. *Run pipeline* → tick **"Simulate a failed release"** → *Run*.
3. The new image deploys, the smoke test fails on purpose, and **"Roll back to previous image"** restores the last good tag.

## Recording checklist for the LinkedIn video
1. Repo tour (Dockerfile, pipeline YAML, Terraform)
2. `git push` → pipeline starts on its own
3. Test results tab → ACR repository tags → App Service deployment center
4. Live site showing the new Build ID
5. App Insights live metrics / alerts

## Clean up
`terraform destroy`  or  `az group delete -n rg-codealpha-cicd --yes`

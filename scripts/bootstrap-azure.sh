#!/usr/bin/env bash
# Provision the Azure resources for Task 1 with the Azure CLI
# (alternative to infra/terraform). Idempotent: safe to re-run.
#
#   az login
#   ./scripts/bootstrap-azure.sh
set -euo pipefail

LOCATION="${LOCATION:-westeurope}"
RG="${RG:-rg-codealpha-cicd}"
ACR="${ACR:-acrcodealphamga}"
PLAN="${PLAN:-asp-codealpha}"
APP="${APP:-app-codealpha-mga}"
IMAGE_REPO="${IMAGE_REPO:-codealpha-webapp}"
SKU="${SKU:-B1}"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

log "Resource group $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

log "Azure Container Registry $ACR"
az acr create -g "$RG" -n "$ACR" --sku Basic --admin-enabled false -o none
ACR_ID=$(az acr show -n "$ACR" --query id -o tsv)
ACR_SERVER=$(az acr show -n "$ACR" --query loginServer -o tsv)

log "Seed image (so the Web App has something to start)"
az acr build -r "$ACR" -t "$IMAGE_REPO:latest" -f Dockerfile . -o none

log "App Service plan $PLAN ($SKU, Linux)"
az appservice plan create -g "$RG" -n "$PLAN" --is-linux --sku "$SKU" -o none

log "Web App $APP"
if ! az webapp show -g "$RG" -n "$APP" -o none 2>/dev/null; then
  az webapp create -g "$RG" -p "$PLAN" -n "$APP" \
    --deployment-container-image-name "$ACR_SERVER/$IMAGE_REPO:latest" -o none
fi

log "Managed identity + AcrPull"
PRINCIPAL=$(az webapp identity assign -g "$RG" -n "$APP" --query principalId -o tsv)
az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role AcrPull --scope "$ACR_ID" -o none 2>/dev/null || true
az webapp config set -g "$RG" -n "$APP" \
  --generic-configurations '{"acrUseManagedIdentityCreds": true, "healthCheckPath": "/health"}' -o none
az webapp update -g "$RG" -n "$APP" --https-only true -o none

log "App settings"
az webapp config appsettings set -g "$RG" -n "$APP" -o none \
  --settings WEBSITES_PORT=3000 APP_ENVIRONMENT=production

log "Container logging"
az webapp log config -g "$RG" -n "$APP" --docker-container-logging filesystem -o none

cat <<EOF

Done.
  ACR login server : $ACR_SERVER
  Web App URL      : https://$APP.azurewebsites.net
Next: create the two service connections in Azure DevOps (see docs/SETUP.md)
and update the variables block at the top of azure-pipelines.yml.
EOF

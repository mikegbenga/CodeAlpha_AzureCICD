#!/usr/bin/env bash
# Watch recent Azure Pipelines runs and the live Web App from the terminal.
# Requires: az CLI + azure-devops extension (az extension add --name azure-devops)
#
#   export AZDO_ORG=https://dev.azure.com/<your-org>  AZDO_PROJECT=<project>
#   ./scripts/monitor-pipeline.sh
set -euo pipefail

: "${AZDO_ORG:?set AZDO_ORG, e.g. https://dev.azure.com/myorg}"
: "${AZDO_PROJECT:?set AZDO_PROJECT}"
PIPELINE="${PIPELINE:-CodeAlpha_AzureCICD}"
RG="${RG:-rg-codealpha-cicd}"
APP="${APP:-app-codealpha-mga}"

az devops configure --defaults organization="$AZDO_ORG" project="$AZDO_PROJECT"

echo "== Last 10 runs of $PIPELINE"
az pipelines runs list --pipeline-name "$PIPELINE" --top 10 \
  --query "[].{id:id, branch:sourceBranch, status:status, result:result, finished:finishTime}" -o table

echo; echo "== Live health"
curl -fsS "https://$APP.azurewebsites.net/health" && echo || echo "UNHEALTHY"

echo; echo "== Running image"
az webapp config show -g "$RG" -n "$APP" --query linuxFxVersion -o tsv

echo; echo "== Tail container logs (Ctrl+C to stop)"
az webapp log tail -g "$RG" -n "$APP"

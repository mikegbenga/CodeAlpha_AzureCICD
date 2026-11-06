# CodeAlpha_AzureCICD — CI/CD Pipeline using Azure

**CodeAlpha DevOps Internship · Task 1** — Michael Gbenga Abajemito (Student ID: CA/DF1/326280)

An automated CI/CD pipeline that tests a Node.js web app, builds it into a container image,
pushes it to **Azure Container Registry (ACR)** and deploys it to **Azure App Service
(Web App for Containers)**. The pipeline smoke-tests every release and rolls back by itself if a release fails.

```
 GitHub push ──► Azure Pipelines
                 ├─ Stage 1  CI      : Node 22 unit tests → JUnit results published
                 ├─ Stage 2  Build   : docker build → local container smoke test → push to ACR (:BuildId, :latest)
                 └─ Stage 3  Deploy  : record current image → deploy :BuildId to App Service
                                       → poll /health until it reports this build → rollback on failure
                                    │
         Azure Container Registry ◄─┘  (App Service pulls with Managed Identity + AcrPull, no passwords)
                                    │
         Azure App Service (Linux) ─┴─► Application Insights + Log Analytics + Azure Monitor alerts
```

## What the task asked for, and where it's done

| Requirement | Implementation |
|---|---|
| Automated CI/CD pipeline with Azure Pipelines | [`azure-pipelines.yml`](azure-pipelines.yml): 3 stages that run on every push to `main` and every PR into it |
| Azure Container Registry for container storage | `Docker@2` build/push to ACR, image tagged with the BuildId and `latest`; registry in [`infra/terraform`](infra/terraform/main.tf) |
| Automatic deploys to Azure App Service | `AzureWebAppContainer@1` deployment job, tied to the `codealpha-production` environment (approvals can be added) |
| Pipeline monitoring | Test results tab, a post-deploy smoke test, automatic rollback, App Insights, Log Analytics, alerts on 5xx errors and health checks, [`scripts/monitor-pipeline.sh`](scripts/monitor-pipeline.sh) |
| DevOps concepts | IaC (Terraform + az CLI), immutable image tags, a multi-stage Dockerfile, a non-root container, health checks, managed identity, shift-left testing |

## Repository layout

```
.
├── app/                    Node.js app (no dependencies)
│   ├── src/server.js       HTTP server: /, /health, /api/info, structured logs, graceful shutdown
│   ├── public/             Landing page that shows the running build
│   └── test/               node:test suite (6 tests)
├── Dockerfile              Multi-stage: tests run inside the build, then a slim non-root runtime with HEALTHCHECK
├── azure-pipelines.yml     The CI/CD pipeline
├── infra/terraform/        RG, ACR, App Service plan + Web App, MI/AcrPull, Log Analytics, App Insights, alerts
├── scripts/
│   ├── bootstrap-azure.sh  Same infrastructure with the az CLI
│   └── monitor-pipeline.sh Run history, live health, running image, log tail
└── docs/SETUP.md           Step-by-step setup in Azure + Azure DevOps
```

## Run locally

```bash
cd app && npm test && npm start           # http://localhost:3000
# or as a container
docker build -t codealpha-webapp .
docker run --rm -p 3000:3000 codealpha-webapp
curl localhost:3000/health
```

## Deploy to Azure (summary)

1. **Provision:** `cd infra/terraform && cp terraform.tfvars.example terraform.tfvars && terraform init && terraform apply`
   (or `./scripts/bootstrap-azure.sh`).
2. **Azure DevOps:** create the project and two service connections:
   *Docker Registry → ACR* (`sc-acr-codealpha`) and *Azure Resource Manager* (`sc-azure-codealpha`).
3. **Pipeline:** *Pipelines → New → GitHub → this repo → Existing YAML → `/azure-pipelines.yml`*.
   If your resource names differ, update the `variables:` block.
4. Push to `main` and watch all three stages pass. Then open `https://<webAppName>.azurewebsites.net`.

Full walkthrough with screenshots checklist: **[docs/SETUP.md](docs/SETUP.md)**.

## Monitoring & troubleshooting

* **Pipeline:** the run summary shows stage timings, the *Tests* tab shows JUnit results, and *Environments → codealpha-production* lists deployment history.
* **App:** Application Insights (requests, failures, live metrics), plus Log Analytics `AppServiceConsoleLogs` for the JSON request logs.
* **Alerts:** email when there are more than 5 HTTP 5xx responses in 5 minutes, or when the health check drops below 100%.
* **Common fixes:** a 503 after deploy usually means `WEBSITES_PORT` is not 3000. An image pull error means the AcrPull role assignment is missing or `acrUseManagedIdentityCreds` is false. A failing smoke test means the new build triggered the rollback step, so check its logs.

## License
MIT

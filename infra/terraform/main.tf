terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  tags = {
    project    = "codealpha-devops-task1"
    owner      = "michael-gbenga-abajemito"
    managed_by = "terraform"
  }
}

# ---------------------------------------------------------------- Resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------- Container registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false # App Service pulls with managed identity, pipeline pushes with a service principal
  tags                = local.tags
}

# ---------------------------------------------------------------- Monitoring
resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-${var.web_app_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "appi" {
  name                = "appi-${var.web_app_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "Node.JS"
  tags                = local.tags
}

# ---------------------------------------------------------------- App Service
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.web_app_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.tags
}

resource "azurerm_linux_web_app" "app" {
  name                = var.web_app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = var.app_service_sku != "F1"
    container_registry_use_managed_identity = true
    health_check_path                       = "/health"
    health_check_eviction_time_in_min       = 5
    ftps_state                              = "Disabled"
    minimum_tls_version                     = "1.2"
    http2_enabled                           = true

    application_stack {
      # First deploy uses :latest; the pipeline then pins each release to its BuildId tag
      docker_image_name   = "${var.image_repository}:latest"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
  }

  app_settings = {
    WEBSITES_PORT                         = "3000"
    APP_ENVIRONMENT                       = "production"
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.appi.connection_string
    DOCKER_ENABLE_CI                      = "false"
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  lifecycle {
    # The pipeline owns the running image tag and build app settings
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      app_settings["APP_VERSION"],
      app_settings["BUILD_ID"],
    ]
  }
}

# Let the Web App pull images from ACR without registry passwords
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# Ship App Service logs to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "app_diag" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  enabled_log { category = "AppServicePlatformLogs" }
}

# ---------------------------------------------------------------- Alerts
resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-${var.web_app_name}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "codealpha"

  email_receiver {
    name          = "owner"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "http5xx" {
  name                = "alert-${var.web_app_name}-5xx"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_web_app.app.id]
  description         = "More than 5 HTTP 5xx responses in 5 minutes"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

resource "azurerm_monitor_metric_alert" "health" {
  name                = "alert-${var.web_app_name}-health"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_web_app.app.id]
  description         = "Health check status dropped below 100%"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HealthCheckStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

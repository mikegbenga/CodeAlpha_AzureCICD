output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "web_app_url" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "web_app_name" {
  value = azurerm_linux_web_app.app.name
}

output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "application_insights_name" {
  value = azurerm_application_insights.appi.name
}

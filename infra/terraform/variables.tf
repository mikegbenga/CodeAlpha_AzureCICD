variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  type    = string
  default = "rg-codealpha-cicd"
}

variable "acr_name" {
  description = "Globally unique, 5-50 lowercase alphanumerics"
  type        = string
  default     = "acrcodealphamga"

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "ACR name must be 5-50 lowercase letters or digits."
  }
}

variable "web_app_name" {
  description = "Globally unique; becomes <name>.azurewebsites.net"
  type        = string
  default     = "app-codealpha-mga"
}

variable "image_repository" {
  type    = string
  default = "codealpha-webapp"
}

variable "app_service_sku" {
  description = "B1 is the cheapest SKU that supports always_on and health checks; F1 works for demos"
  type        = string
  default     = "B1"
}

variable "alert_email" {
  description = "Where Azure Monitor alerts are sent"
  type        = string
}

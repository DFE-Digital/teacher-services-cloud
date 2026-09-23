variable "subscription_id" {
  description = "Azure subscription ID where resources will be deployed."
  type        = string
  default = "5c83eb53-a94f-4778-b258-1f33efe49655"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "uksouth"
}

variable "name_prefix" {
  description = "Lowercase prefix used in Azure resource names."
  type        = string
  default     = "s189d01"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name_prefix))
    error_message = "name_prefix must contain 3-20 lowercase letters, numbers, or hyphens."
  }
}

variable "container_image" {
  description = "Public container image to run."
  type        = string
  default     = "ghcr.io/dfe-digital/teacher-services-cloud:nginx-unprivileged-1.27.3-alpine3.20"
}

variable "container_port" {
  description = "HTTP port exposed by the container."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port > 0 && var.container_port < 65536
    error_message = "container_port must be a valid TCP port."
  }
}

variable "container_cpu" {
  description = "Number of CPU cores allocated to the container."
  type        = number
  default     = 0.5
}

variable "container_memory_gb" {
  description = "Memory in GB allocated to the container."
  type        = number
  default     = 1
}

variable "postgres_version" {
  description = "PostgreSQL Flexible Server major version."
  type        = string
  default     = "16"
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username."
  type        = string
  default     = "pgadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password. Leave null to generate one."
  type        = string
  sensitive   = true
  default     = null
}

variable "vnet_address_space" {
  description = "Address space for the deployment VNet."
  type        = list(string)
  default     = ["10.30.0.0/16"]
}

variable "container_app_subnet_prefix" {
  description = "Subnet for the VNet-integrated Container Apps environment."
  type        = string
  default     = "10.30.1.0/27"
}

variable "postgres_subnet_prefix" {
  description = "Delegated subnet for PostgreSQL Flexible Server."
  type        = string
  default     = "10.30.2.0/28"
}

variable "tags" {
  description = "Additional Azure resource tags."
  type        = map(string)
  default     = {}
}

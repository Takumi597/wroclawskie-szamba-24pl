terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Variables
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "medusashop"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
  default     = "dev"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "db_storage_mb" {
  description = "Database storage in MB"
  type        = number
  default   = 32768
}

variable "db_sku_name" {
  description = "Database SKU ( B_Standard_B1ms, B_Standard_B2s, GP_Standard_D2s_v3, "
  type        = string
  default   = "B_Standard_B2s"
}

variable "enable_geo_backup" {
  description = "Geo-backup"
  type        = bool
  default   = false
}

variable "enable_ha" {
  description = "High Availability"
  type        = bool
  default   = false
}

variable "enable_read_replica" {
  description = "Read Replica - Horizontal Scaling"
  type        = bool
  default   = false
}

variable "medusa_publishable_key" {
  description = "Medusa publishable API key for storefront - leave empty for initial deployment, set later via Azure CLI after getting key from admin dashboard"
  type        = string
  default     = "PLACEHOLDER_UPDATE_AFTER_DEPLOYMENT"
  sensitive   = true
}

# Generate random strings for secrets
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "random_password" "cookie_secret" {
  length  = 64
  special = true
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]

  tags = azurerm_resource_group.main.tags
}

# Subnet for App Service
resource "azurerm_subnet" "app_subnet" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "appservice-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
  depends_on = [azurerm_virtual_network.main]
}

# Subnet for Database
resource "azurerm_subnet" "db_subnet" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
  depends_on = [azurerm_virtual_network.main]
}

# Subnet for Redis
resource "azurerm_subnet" "redis_subnet" {
  name                 = "snet-redis"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Subnet for Container Instances
resource "azurerm_subnet" "aci_subnet" {
  name                 = "snet-aci"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.4.0/24"]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
  depends_on = [azurerm_virtual_network.main]
}

# Network Security Group for App
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-app-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.main.tags
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-${var.project_name}-${var.environment}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "14"
  delegated_subnet_id    = azurerm_subnet.db_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  administrator_login    = "medusaadmin"
  administrator_password = var.postgres_admin_password
  zone                   = "1"
  storage_mb             = var.db_storage_mb
  sku_name               = var.db_sku_name
  backup_retention_days  = 7
  geo_redundant_backup_enabled= var.enable_geo_backup
  
  public_network_access_enabled = false
  timeouts {
  	create = "60m"
  	update = "60m"
  	delete = "60m"
  }
  dynamic "high_availability" {
  	for_each=var.enable_ha ? [1] : []
  	content {
  		mode="ZoneRedundant"
  	}
  }

  depends_on = [azurerm_subnet.db_subnet,azurerm_private_dns_zone_virtual_network_link.postgres]

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_postgresql_flexible_server" "replica" {
  count			 = var.enable_read_replica ? 1 : 0
  name                   = "psql-${var.project_name}-${var.environment}-replica"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  create_mode		 = "Replica"
  source_server_id	 = azurerm_postgresql_flexible_server.main.id
  tags = merge(azurerm_resource_group.main.tags,{ Role = "ReadReplica" })
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "medusa" {
  name      = "medusa"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags
}

# Link DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "postgres-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id

  tags = azurerm_resource_group.main.tags
}

# Redis Cache
resource "azurerm_redis_cache" "main" {
  name                = "redis-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  non_ssl_port_enabled = false
  minimum_tls_version = "1.2"
  # subnet_id           = azurerm_subnet.redis_subnet.id

  redis_configuration {
    authentication_enabled = true
  }

  tags = azurerm_resource_group.main.tags
}

# Storage Account for product images
resource "azurerm_storage_account" "main" {
  name                     = "st${var.project_name}${var.environment}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "HEAD", "POST", "PUT"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = azurerm_resource_group.main.tags
}

# Storage Container
resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "blob"
}

# Azure Container Registry for Docker images
resource "azurerm_container_registry" "main" {
  name                = "acr${var.project_name}${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"  # Use Basic for student subscription (Standard for production)
  admin_enabled       = true     # Enable admin user for CI/CD

  tags = azurerm_resource_group.main.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = azurerm_resource_group.main.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "Node.JS"

  tags = azurerm_resource_group.main.tags
}

# App Service Plan (B2 for production, B1 for dev)
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.environment == "prod" ? "B2" : "B1"

  tags = azurerm_resource_group.main.tags
}

# App Service for Medusa
resource "azurerm_linux_web_app" "main" {
  name                = "app-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on                               = var.environment == "prod" ? true : false
    app_command_line                        = "cd server && npm run predeploy && npm run start"
    http2_enabled                           = true
    ftps_state                              = "Disabled"
    minimum_tls_version                     = "1.2"
    vnet_route_all_enabled                  = true
    health_check_path                       = "/health"
    health_check_eviction_time_in_min       = 2

    application_stack {
      # docker_image_name   = "medusa:latest"
      # docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
      # docker_registry_username = azurerm_container_registry.main.admin_username
      # docker_registry_password = azurerm_container_registry.main.admin_password
      node_version = "20-lts"
    }

    cors {
      allowed_origins = ["*"]
      support_credentials = false
    }
  }

  app_settings = {
    "WEBSITES_PORT"                = "9000"
    # "DOCKER_ENABLE_CI"             = "true"  # Enable continuous deployment from ACR
    "WORKER_MODE"                  = "server"  # Run in server mode (handles API + background tasks)

    # DNS Configuration for Private DNS Zone resolution
    "WEBSITE_DNS_SERVER"           = "168.63.129.16"  # Azure DNS server required for private DNS zones

    # Database
    "DATABASE_URL" = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.medusa.name}"
    
    # Redis
    "REDIS_URL" = "rediss://:${azurerm_redis_cache.main.primary_access_key}@${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port}/0"
    
    # Secrets
    "JWT_SECRET"    = random_password.jwt_secret.result
    "COOKIE_SECRET" = random_password.cookie_secret.result
    
    # CORS - Allow storefront and admin dashboard
    "STORE_CORS"  = "https://storefront-${var.project_name}-${var.environment}.azurewebsites.net"
    "ADMIN_CORS"  = "https://app-${var.project_name}-${var.environment}.azurewebsites.net"
    "AUTH_CORS"   = "https://storefront-${var.project_name}-${var.environment}.azurewebsites.net,https://app-${var.project_name}-${var.environment}.azurewebsites.net"
    
    # Medusa Configuration
    "NODE_ENV" = "production"
    "MEDUSA_DISABLE_TELEMETRY" = "true"
    "MEDUSA_BACKEND_URL" = "https://app-${var.project_name}-${var.environment}.azurewebsites.net"
    
    # Storage
    "AZURE_STORAGE_ACCOUNT_NAME" = azurerm_storage_account.main.name
    "AZURE_STORAGE_ACCOUNT_KEY"  = azurerm_storage_account.main.primary_access_key
    "AZURE_STORAGE_CONTAINER"    = azurerm_storage_container.uploads.name
    
    # Application Insights
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
  }

  identity {
    type = "SystemAssigned"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
  depends_on = [azurerm_postgresql_flexible_server.main,azurerm_redis_cache.main,azurerm_storage_account.main,azurerm_application_insights.main]
  tags = azurerm_resource_group.main.tags
}

# VNet Integration for App Service
resource "azurerm_app_service_virtual_network_swift_connection" "main" {
  app_service_id = azurerm_linux_web_app.main.id
  subnet_id      = azurerm_subnet.app_subnet.id
}

# Storefront App Service
resource "azurerm_linux_web_app" "storefront" {
  name                = "storefront-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on = true
    app_command_line = "./node_modules/next/dist/bin/next start -p $PORT"

    application_stack {
      #docker_image_name   = "storefront:latest"
      #docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
      node_version = "20-lts"
    }

    #container_registry_use_managed_identity = true
  }

  app_settings = {
    "WEBSITES_PORT"                   = "8000"
    # "SCM_DO_BUILD_DURING_DEPLOYMENT"  = "true"
    # "DOCKER_ENABLE_CI"              = "true"

    # Medusa Backend URL (server-side only, used by middleware)
    "MEDUSA_BACKEND_URL" = "https://${azurerm_linux_web_app.main.default_hostname}"

    # Storefront Public Configuration (client-side accessible)
    "MEDUSA_PUBLISHABLE_KEY" = var.medusa_publishable_key
    "NEXT_PUBLIC_BASE_URL"               = "https://storefront-${var.project_name}-${var.environment}.azurewebsites.net"
    "NEXT_PUBLIC_DEFAULT_REGION"         = "pl"

    # Next.js Configuration
    "REVALIDATE_SECRET"       = random_password.revalidate_secret.result
    "NEXT_TELEMETRY_DISABLED" = "1"
    "NODE_ENV"                = "production"

    # Application Insights
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.main.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
  }

  identity {
    type = "SystemAssigned"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  depends_on = [azurerm_linux_web_app.main, azurerm_application_insights.main]
  tags = azurerm_resource_group.main.tags
}

# Grant Storefront App Service access to ACR
# resource "azurerm_role_assignment" "storefront_acr_pull" {
#   scope                = azurerm_container_registry.main.id
#   role_definition_name = "AcrPull"
#   principal_id         = azurerm_linux_web_app.storefront.identity[0].principal_id
# }

# Random password for Next.js revalidation secret
resource "random_password" "revalidate_secret" {
  length  = 32
  special = true
}

# Outputs
output "app_service_name" {
  value = azurerm_linux_web_app.main.name
}

output "app_service_default_hostname" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "redis_hostname" {
  value = azurerm_redis_cache.main.hostname
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "medusa_admin_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}/app"
}

output "database_sku" {
  value = azurerm_postgresql_flexible_server.main.sku_name
  description = "Current DB SKU"
}

output "database_backup_type" {
  value = var.enable_geo_backup ? "Geo-Redundant" : "Local"
  description = "Current redundancy level"
}

output "database_ha_enabled" {
  value = var.enable_ha
  description = "HA Status"
}

output "database_replica_count" {
  value = var.enable_read_replica ? 1 : 0
  description = "Current amount of read replicas"
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
  description = "Azure Container Registry login server URL"
}

output "acr_admin_username" {
  value     = azurerm_container_registry.main.admin_username
  sensitive = true
  description = "ACR admin username"
}

output "acr_admin_password" {
  value     = azurerm_container_registry.main.admin_password
  sensitive = true
  description = "ACR admin password"
}

output "aci_subnet_id" {
  value = azurerm_subnet.aci_subnet.id
  description = "Subnet ID for Azure Container Instances"
}

output "storefront_url" {
  value = "https://${azurerm_linux_web_app.storefront.default_hostname}"
  description = "Storefront URL"
}

output "storefront_service_name" {
  value = azurerm_linux_web_app.storefront.name
  description = "Storefront App Service name"
}

# Medusa v2 Deployment Guide - Azure Infrastructure

Deploy a complete Medusa v2 e-commerce platform on Azure with private infrastructure.

## Architecture

- **Backend App Service**: Medusa v2 API (https://app-medusashop-prod.azurewebsites.net)
- **Storefront App Service**: Next.js customer-facing shop (https://storefront-medusashop-prod.azurewebsites.net)
- **Azure Container Registry**: Private Docker images
- **PostgreSQL Flexible Server**: Private database (VNet-only, no public access)
- **Redis Cache**: SSL-encrypted cache
- **Virtual Network**: Private subnets for App Service, Database, Redis, Container Instances
- **Application Insights**: Monitoring and logs
- **Blob Storage**: File uploads

## Prerequisites

- Active Azure subscription with Contributor permissions
- Azure CLI 2.50+: `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`
- Terraform 1.5+: Install from [terraform.io](https://terraform.io)
- Git

## Step 1: Clone the Repository

```bash
git clone https://github.com/wojtazk/wroclawskie-szamba-24pl
cd wroclawskie-szamba-24pl
```

## Step 2: Azure Setup

```bash
# Login
az login

# List subscriptions
az account list --output table

# Set subscription
az account set --subscription "<your-subscription-id>"

# Create service principal for GitHub Actions
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az ad sp create-for-rbac \
  --name "sp-medusashop-github" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth
```

**Save the entire JSON output** - needed for GitHub Secrets.

## Step 3: GitHub Secrets

Go to: Repository > Settings > Secrets and variables > Actions

Add:

- `AZURE_CREDENTIALS`: Entire JSON from Step 2
- `AZURE_SUBSCRIPTION_ID`: Your subscription ID
- `STAGING_URL`: `https://app-medusashop-prod.azurewebsites.net` (for DAST testing)

## Step 4: Terraform Configuration

```bash
cd infrastructure
nano terraform.tfvars
```

Add:

```hcl
project_name = "medusashop"
environment  = "prod"
location     = "polandcentral"
postgres_admin_password = "YourSecurePassword123!"  # Change this!

# Optional: High Availability & SKU
enable_ha = false
enable_geo_backup = false
enable_read_replica = false
postgres_sku = "B_Standard_B1ms"
redis_sku = "Basic"
redis_family = "C"
redis_capacity = 0
```

**Note**: Don't commit `terraform.tfvars` to Git (already in `.gitignore`).

## Step 5: Deploy Infrastructure

```bash
terraform init
terraform plan  # Review ~22 resources
terraform apply # Takes 10-15 minutes
terraform output > ../terraform-outputs.txt
```

Creates: Resource Group, VNet, PostgreSQL, Redis, Storage, ACR, App Services (backend + storefront), Application Insights.

## Step 6: Manual Configuration

Two Azure/Terraform limitations require manual setup:

```bash
# Enable PostgreSQL extensions
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az rest --method put \
  --uri "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-medusashop-prod/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-medusashop-prod/configurations/azure.extensions?api-version=2022-12-01" \
  --body '{"properties": {"value": "PGCRYPTO,UUID-OSSP", "source": "user-override"}}'

# Apply VNet integration (wait 2 min after extensions)
az webapp vnet-integration add \
  --name app-medusashop-prod \
  --resource-group rg-medusashop-prod \
  --vnet vnet-medusashop-prod \
  --subnet snet-app

# Restart backend
az webapp restart --name app-medusashop-prod --resource-group rg-medusashop-prod
```

## Step 7: Deploy via GitHub Actions

```bash
cd ..
git add .
git commit -m "Initial deployment"
git push origin main
```

Go to GitHub > Actions > Watch "Deploy Medusa to Azure (Docker)"

Workflow does: SAST scan, build Docker images (medusa, storefront, db-seeder), push to ACR, deploy both apps, health checks, database seeding, security monitoring.

Takes ~10-15 minutes.

**Verify:**

```bash
curl https://app-medusashop-prod.azurewebsites.net/health  # Should return: OK
```

## Step 8: Database Seeding (Optional)

**Automatic**: GitHub Actions seeds database on deployment.

**Manual** (if needed):

```bash
./run-seeder.sh
```

**Admin Credentials:** `admin@medusajs.com` / `supersecret` (change after first login!)

## Step 9: Configure Storefront

**Storefront is deployed but needs API key to work properly.**

1. Login: https://app-medusashop-prod.azurewebsites.net/app
2. Settings > Publishable API Keys > Create
3. Copy the key (starts with `pk_`)
4. Run:
   ```bash
   ./update-storefront-api-key.sh pk_your_actual_key_here
   ```

**Verify** (wait 60s):

```bash
curl -I https://storefront-medusashop-prod.azurewebsites.net/  # Should return 200 OK
```

## Step 10: Access Your Application

**URLs:**

- Storefront: https://storefront-medusashop-prod.azurewebsites.net/
- Admin: https://app-medusashop-prod.azurewebsites.net/app
- API: https://app-medusashop-prod.azurewebsites.net/store

**Admin Login:** `admin@medusajs.com` / `supersecret`

## Troubleshooting

**ENOTFOUND Database Errors**: Re-run Step 6 (VNet integration + restart)

**PostgreSQL Extension Errors**: Re-run PostgreSQL extension command from Step 6

**Storefront Not Working**: Ensure API key is set via `./update-storefront-api-key.sh`

**GitHub Actions Fails**: Check `AZURE_CREDENTIALS` and `AZURE_SUBSCRIPTION_ID` secrets

**View Logs**:

```bash
az webapp log tail --name app-medusashop-prod --resource-group rg-medusashop-prod
```

## Resources

- [Medusa Docs](https://docs.medusajs.com/)
- [Azure App Service Docs](https://docs.microsoft.com/en-us/azure/app-service/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

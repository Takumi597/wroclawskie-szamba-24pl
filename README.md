# WroclawskieSzamba24.pl

<img width="100%" alt="Screenshot_20251012_172221" src="https://github.com/user-attachments/assets/79b3a52e-2c79-44a4-a85e-2b96cbd2bf07" />

## Resources

### Images

- https://pixabay.com/photos/sewage-truck-faeces-cesspool-5940760/
- https://pixabay.com/vectors/poo-emoji-poop-brown-smiley-6783251/

### Music

- generated with suno's v5 beta model (https://suno.com/)

## Azure deploy resources

- https://learn.microsoft.com/en-us/azure/app-service/configure-language-nodejs?pivots=platform-linux
- https://learn.microsoft.com/en-us/azure/app-service/deploy-zip?tabs=cli#enable-build-automation-for-zip-deploy
- https://learn.microsoft.com/en-us/azure/app-service/deploy-local-git?tabs=cli
- https://learn.microsoft.com/en-us/azure/app-service/quickstart-nodejs?tabs=linux&pivots=development-environment-vscode
- https://learn.microsoft.com/en-us/azure/app-service/deploy-github-actions?tabs=userlevel%2Cnodejs
- https://docs.medusajs.com/
- https://registry.terraform.io/providers/hashicorp/azurerm/latest
- https://registry.terraform.io/providers/hashicorp/azurerm/4.49.0/docs/resources/linux_web_app
- https://github.com/Azure/webapps-deploy
- and probably more

## Docker

It is also possible to deploy the apps as docker containers, buuuut, figure it out on your own, you're a big boy.

Check out the initial `wroclawskie-szamba` setup 😵‍💫: https://github.com/wojtazk/wroclawskie-szamba/

## Azure Guide

Deploy a complete Medusa v2 e-commerce platform on Azure with private infrastructure.

### Prerequisites

- Active Azure subscription with Contributor permissions
- Azure CLI 2.50+ ([learn.microsoft.net](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
- Terraform 1.5+m ([terraform.io](https://terraform.io))
- Git ([git-scm.com](https://git-scm.com/))

### Architecture

- **Backend App Service**: Medusa v2 API (https://app-medusashop-prod.azurewebsites.net)
- **Storefront App Service**: Next.js customer-facing shop (https://storefront-medusashop-prod.azurewebsites.net)
- **Azure Container Registry**: Private Docker images
- **PostgreSQL Flexible Server**: Private database (VNet-only, no public access)
- **Redis Cache**: SSL-encrypted cache
- **Virtual Network**: Private subnets for App Service, Database, Redis, Container Instances
- **Application Insights**: Monitoring and logs
- **Blob Storage**: File uploads

### Step 1: Clone the Repository

```bash
git clone https://github.com/Takumi597/wroclawskie-szamba-24pl.git
cd wroclawskie-szamba-24pl
```

### Step 2: Azure Setup

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

### Step 3: GitHub Secrets

Go to: Repository > Settings > Secrets and variables > Actions

Add:

- `AZURE_CREDENTIALS`: Entire JSON from Step 2
- `AZURE_SUBSCRIPTION_ID`: Your subscription ID
- `STAGING_URL`: `https://app-medusashop-prod.azurewebsites.net` (for DAST testing)

### Step 4: Terraform Configuration

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

### Step 5: Deploy Infrastructure

```bash
terraform init
terraform plan  # Review ~22 resources
terraform apply # Takes 10-15 minutes (redis is amazing on Azure)
terraform output > ../terraform-outputs.txt
```

Creates: Resource Group, VNet, PostgreSQL, Redis, Storage, ACR, App Services (backend + storefront), Application Insights.

### Step 6: Manual Configuration

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

### Step 7: Deploy via GitHub Actions

**Note**: You have to enable actions on your repo

```bash
cd ..
git add .
git commit -m "Initial deployment"
git push origin main
```

Go to GitHub > Actions > Watch "Deploy Medusa to Azure (Docker)"

Workflow does: SAST scan, build Docker images (db-seeder), push to ACR, build & deploy medusa and storefront, security monitoring.

Takes ~10-15 minutes.

**Verify:**

```bash
curl https://app-medusashop-prod.azurewebsites.net/health  # Should return: OK
```

### Step 8: Database Seeding (Optional)

**Automatic**: Seed the database with "Database seeder" GitHub Action.

**Manual** (if needed):

```bash
./run-seeder.sh
```

**Admin Credentials:** `admin@medusajs.com` / `supersecret` (change after first login!)

### Step 9: Configure Storefront

**Storefront is deployed but needs API key to work properly.**

<img width="100%" alt="Screenshot_20251012_120447" src="https://github.com/user-attachments/assets/4a8273ad-a84f-461d-805d-2890591aacae" />

1. Login: https://app-medusashop-prod.azurewebsites.net/app
2. Settings > Publishable API Keys > Create
3. Copy the key (starts with `pk_`)
4. Run:
   ```bash
   ./update-storefront-api-key.sh pk_your_actual_key_here
   ```

**Note**: The key can also be updated in Azure portal (Web App -> settings -> Environment Variables)

**Verify** (wait for a while):

```bash
curl -I https://storefront-medusashop-prod.azurewebsites.net/  # Should return 200 OK
```

### Step 10: Access Your Application

**URLs:**

- Storefront: https://storefront-medusashop-prod.azurewebsites.net/
- Admin: https://app-medusashop-prod.azurewebsites.net/app
- API: https://app-medusashop-prod.azurewebsites.net/store

**Admin Login:** User can be created with db-seeder (Check database seeding)

### Troubleshooting

**ENOTFOUND Database Errors**: Re-run Step 6 (VNet integration + restart)

**PostgreSQL Extension Errors**: Re-run PostgreSQL extension command from Step 6

**Storefront Not Working**: Ensure API key is set in Storefront

**GitHub Actions Fails**: Check `AZURE_CREDENTIALS` and `AZURE_SUBSCRIPTION_ID` secrets

**GitHub Actions Fails**: Check resource names (Container Registry, storefrotn Web App etc)

**View Logs**:

```bash
az webapp log tail --name app-medusashop-prod --resource-group rg-medusashop-prod
```

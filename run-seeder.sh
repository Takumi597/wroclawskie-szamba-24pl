#!/bin/bash
set -e

echo "=== Running Database Seeder ==="

# Configuration
RESOURCE_GROUP="rg-medusashop-prod"
ACR_NAME="acrmedusashopprod"
CONTAINER_NAME="medusa-seeder-$(date +%s)"
IMAGE="${ACR_NAME}.azurecr.io/db-seeder:latest"

# Get PostgreSQL and Redis connection strings from App Service
echo "Fetching connection strings from App Service..."
DATABASE_URL=$(az webapp config appsettings list \
  --name app-medusashop-prod \
  --resource-group $RESOURCE_GROUP \
  --query "[?name=='DATABASE_URL'].value | [0]" \
  -o tsv)

REDIS_URL=$(az webapp config appsettings list \
  --name app-medusashop-prod \
  --resource-group $RESOURCE_GROUP \
  --query "[?name=='REDIS_URL'].value | [0]" \
  -o tsv)

# Get ACR credentials
echo "Fetching ACR credentials..."
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Run seeder as Azure Container Instance
echo "Running seeder container..."
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image $IMAGE \
  --registry-login-server "${ACR_NAME}.azurecr.io" \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --environment-variables \
    DATABASE_URL="$DATABASE_URL" \
    REDIS_URL="$REDIS_URL" \
    NODE_ENV=production \
  --restart-policy Never \
  --cpu 1 \
  --memory 1.5 \
  --location westeurope

echo "Seeder container created: $CONTAINER_NAME"
echo "Waiting for seeder to complete..."

# Wait for container to complete
az container wait \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --condition-type Succeeded

echo "Checking seeder logs..."
az container logs \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME

# Clean up container
echo "Cleaning up container..."
az container delete \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --yes

echo ""
echo "✅ Database seeding completed!"
echo ""
echo "Admin credentials:"
echo "  Email: admin@medusajs.com"
echo "  Password: supersecret"
echo ""
echo "Access admin dashboard at: https://app-medusashop-prod.azurewebsites.net/app"

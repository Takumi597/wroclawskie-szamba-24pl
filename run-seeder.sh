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

# Get ACR credentials using REST API (workaround for Azure CLI bug)
echo "Fetching ACR credentials..."
ACR_CREDS=$(az rest --method post --uri "https://management.azure.com/subscriptions/12869276-74ab-4aad-81e0-fbe8a3f566f3/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME/listCredentials?api-version=2023-01-01-preview")
ACR_USERNAME=$(echo $ACR_CREDS | jq -r '.username')
ACR_PASSWORD=$(echo $ACR_CREDS | jq -r '.passwords[0].value')

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

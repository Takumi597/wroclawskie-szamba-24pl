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

# Get VNet and Subnet info
echo "Fetching VNet configuration..."
VNET_NAME="vnet-medusashop-prod"
SUBNET_NAME="snet-aci"
SUBNET_ID=$(az network vnet subnet show \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_NAME \
  --query "id" -o tsv)

# Get location from VNet to ensure consistency
LOCATION=$(az network vnet show \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --query "location" -o tsv)

# Get ACR credentials using REST API (workaround for Azure CLI bug)
echo "Fetching ACR credentials..."
ACR_USERNAME=$(az rest --method post --uri "https://management.azure.com/subscriptions/12869276-74ab-4aad-81e0-fbe8a3f566f3/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME/listCredentials?api-version=2023-01-01-preview" --query "username" -o tsv)
ACR_PASSWORD=$(az rest --method post --uri "https://management.azure.com/subscriptions/12869276-74ab-4aad-81e0-fbe8a3f566f3/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME/listCredentials?api-version=2023-01-01-preview" --query "passwords[0].value" -o tsv)

# Run seeder as Azure Container Instance
echo "Running seeder container in location: $LOCATION"
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image $IMAGE \
  --os-type Linux \
  --subnet $SUBNET_ID \
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
  --location $LOCATION

echo "Seeder container created: $CONTAINER_NAME"
echo "Waiting for seeder to complete..."

# Wait for container to complete (polling loop)
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  STATE=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_NAME \
    --query "instanceView.state" -o tsv 2>/dev/null || echo "Unknown")

  if [ "$STATE" = "Succeeded" ] || [ "$STATE" = "Failed" ] || [ "$STATE" = "Terminated" ]; then
    echo "Container finished with state: $STATE"
    break
  fi

  echo "Current state: $STATE (attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)"
  sleep 5
  ATTEMPT=$((ATTEMPT+1))
done

echo ""
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

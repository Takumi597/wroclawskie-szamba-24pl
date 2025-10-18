#!/bin/bash
set -e

echo "=== Update Storefront API Key ==="
echo ""

# Check if API key was provided as argument
if [ -z "$1" ]; then
  echo "Usage: ./update-storefront-api-key.sh <publishable-api-key>"
  echo ""
  echo "Steps to get the API key:"
  echo "1. Login to admin dashboard: https://app-medusashop-prod.azurewebsites.net/app"
  echo "2. Navigate to: Settings > Publishable API Keys"
  echo "3. Create a new API key (or copy existing one)"
  echo "4. Run this script with the key: ./update-storefront-api-key.sh pk_xxxxx"
  echo ""
  exit 1
fi

API_KEY="$1"
RESOURCE_GROUP="rg-medusashop-prod"
STOREFRONT_NAME="storefront-medusashop-prod"

# Validate API key format
if [[ ! "$API_KEY" =~ ^pk_ ]]; then
  echo "❌ Error: Invalid API key format. Key should start with 'pk_'"
  exit 1
fi

echo "Updating storefront with API key: ${API_KEY:0:10}..."
echo ""

# Update the app setting
az webapp config appsettings set \
  --name $STOREFRONT_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY="$API_KEY" \
  --output none

echo "✅ API key updated successfully!"
echo ""
echo "Restarting storefront to apply changes..."

# Restart the storefront
az webapp restart \
  --name $STOREFRONT_NAME \
  --resource-group $RESOURCE_GROUP \
  --output none

echo "✅ Storefront restarted!"
echo ""
echo "Wait 30-60 seconds, then visit: https://storefront-medusashop-prod.azurewebsites.net/"
echo ""

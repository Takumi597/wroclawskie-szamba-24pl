#!/bin/bash

set -e

DOMAIN="localhost2137.xyz"
RG="rg-medusashop-prod"

az webapp config hostname add \
  --webapp-name storefront-medusashop-prod \
  --resource-group $RG \
  --hostname $DOMAIN

az webapp config hostname add \
  --webapp-name storefront-medusashop-prod \
  --resource-group $RG \
  --hostname www.$DOMAIN

az webapp config hostname add \
  --webapp-name app-medusashop-prod \
  --resource-group $RG \
  --hostname admin.$DOMAIN

az webapp config hostname add \
  --webapp-name app-medusashop-prod \
  --resource-group $RG \
  --hostname api.$DOMAIN

az webapp config appsettings set \
  --name app-medusashop-prod \
  --resource-group $RG \
  --settings \
    STORE_CORS="https://$DOMAIN,https://www.$DOMAIN" \
    ADMIN_CORS="https://admin.$DOMAIN" \
    AUTH_CORS="https://$DOMAIN,https://www.$DOMAIN,https://admin.$DOMAIN" \
    MEDUSA_BACKEND_URL="https://api.$DOMAIN"

az webapp config appsettings set \
  --name storefront-medusashop-prod \
  --resource-group $RG \
  --settings \
    MEDUSA_BACKEND_URL="https://api.$DOMAIN" \
    NEXT_PUBLIC_BASE_URL="https://$DOMAIN"

az webapp restart --name app-medusashop-prod --resource-group $RG
az webapp restart --name storefront-medusashop-prod --resource-group $RG

echo ""
echo "Azure configuration complete!"
echo ""

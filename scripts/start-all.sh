#!/bin/bash
RESOURCE_GROUP="rg-medusashop-dev"
echo " Starting resources..."
az postgres flexible-server start --name psql-medusashop-dev --resource-group $RESOURCE_GROUP
az webapp start --name app-medusashop-dev --resource-group $RESOURCE_GROUP
sleep 30
URL=$(az webapp show --name app-medusashop-dev --resource-group $RESOURCE_GROUP --query defaultHostName -o tsv)
echo " Admin: https://$URL/app"

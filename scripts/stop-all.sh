#!/bin/bash
RESOURCE_GROUP="rg-medusashop-dev"
echo " Stopping all resources..."
az webapp stop --name app-medusashop-dev --resource-group $RESOURCE_GROUP
az postgres flexible-server stop --name psql-medusashop-dev --resource-group $RESOURCE_GROUP
echo " Done! "

#!/bin/bash
read -p "Email: " EMAIL
read -sp "Password: " PASS
echo ""
az webapp ssh --name app-medusashop-dev --resource-group rg-medusashop-dev \
  --command "cd /home/site/wwwroot && npx medusa user -e $EMAIL -p $PASS"

#!/bin/bash

set -e

RG="rg-medusashop-prod"
APPINSIGHTS_NAME="appi-medusashop-prod"

WORKSPACE_ID=$(az monitor app-insights component show \
  --app $APPINSIGHTS_NAME \
  --resource-group $RG \
  --query "workspaceResourceId" -o tsv)

az monitor scheduled-query create \
  --name "ids-sql-injection-detection" \
  --resource-group $RG \
  --scopes "$WORKSPACE_ID" \
  --condition "count() > 3" \
  --condition-query "AppRequests | where TimeGenerated > ago(10m) | extend QueryString = tostring(parse_url(Url).[\"Query Parameters\"]) | where QueryString contains \"'\" or QueryString contains \"--\" or QueryString contains \"union\" or QueryString contains \"select\" or QueryString contains \"drop\" or QueryString contains \"exec\" or QueryString contains \"script\" | summarize count()" \
  --description "IDS Alert: SQL Injection attempts detected" \
  --evaluation-frequency 5m \
  --window-size 10m \
  --severity 2 \
  --auto-mitigate false 2>/dev/null || echo "Alert already exists"

az monitor scheduled-query create \
  --name "ids-admin-brute-force" \
  --resource-group $RG \
  --scopes "$WORKSPACE_ID" \
  --condition "count() > 5" \
  --condition-query "AppRequests | where TimeGenerated > ago(5m) | where Url contains \"/admin\" or Url contains \"/app\" | where ResultCode in (401, 403) | extend SourceIP = tostring(client_IP) | summarize count() by SourceIP" \
  --description "IDS Alert: Brute force attack on admin panel detected" \
  --evaluation-frequency 5m \
  --window-size 5m \
  --severity 2 \
  --auto-mitigate false 2>/dev/null || echo "Alert already exists"

az monitor scheduled-query create \
  --name "ids-credential-stuffing" \
  --resource-group $RG \
  --scopes "$WORKSPACE_ID" \
  --condition "count() > 5" \
  --condition-query "AppRequests | where TimeGenerated > ago(5m) | where Url contains \"/auth/login\" or Url contains \"/admin/auth\" | where ResultCode == 401 | extend SourceIP = tostring(client_IP) | summarize count() by SourceIP" \
  --description "IDS Alert: Credential stuffing attack detected" \
  --evaluation-frequency 5m \
  --window-size 5m \
  --severity 2 \
  --auto-mitigate false 2>/dev/null || echo "Alert already exists"

az monitor scheduled-query create \
  --name "ids-ddos-detection" \
  --resource-group $RG \
  --scopes "$WORKSPACE_ID" \
  --condition "count() > 100" \
  --condition-query "AppRequests | where TimeGenerated > ago(1m) | extend SourceIP = tostring(client_IP) | summarize RequestsPerMinute = count() by SourceIP | where RequestsPerMinute > 100 | summarize count()" \
  --description "IDS Alert: Potential DDoS attack detected" \
  --evaluation-frequency 1m \
  --window-size 1m \
  --severity 1 \
  --auto-mitigate false 2>/dev/null || echo "Alert already exists"

az monitor scheduled-query create \
  --name "ids-session-hijacking" \
  --resource-group $RG \
  --scopes "$WORKSPACE_ID" \
  --condition "count() > 0" \
  --condition-query "AppRequests | where TimeGenerated > ago(10m) | extend SessionId = tostring(parse_json(Properties).sessionId) | extend SourceIP = tostring(client_IP) | where isnotempty(SessionId) | summarize UniqueIPs = dcount(SourceIP), Countries = make_set(client_CountryOrRegion) by SessionId | where UniqueIPs > 1 or array_length(Countries) > 1 | summarize count()" \
  --description "IDS Alert: Session hijacking detected" \
  --evaluation-frequency 5m \
  --window-size 10m \
  --severity 2 \
  --auto-mitigate false 2>/dev/null || echo "Alert already exists"

az monitor scheduled-query create \
  --name "ids-port-scanning" \
  --resource-group $RG \
  --scopes "$WORKSPACE_ID" \
  --condition "count() > 0" \
  --condition-query "AzureDiagnostics | where Category == \"ApplicationGatewayFirewallLog\" or ResourceType == \"NETWORKSECURITYGROUPS\" | extend SourceIP = tostring(split(clientIP_s, \":\")[0]) | where TimeGenerated > ago(5m) | summarize DistinctPorts = dcount(serverPort_d), TotalAttempts = count() by SourceIP | where DistinctPorts > 10 and TotalAttempts > 20 | summarize count()" \
  --description "IDS Alert: Port scanning activity detected" \
  --evaluation-frequency 5m \
  --window-size 5m \
  --severity 3 \
  --auto-mitigate false 2>/dev/null || echo "Alert already exists"

echo ""
echo "IDS/IPS alerts deployment complete!"
echo ""

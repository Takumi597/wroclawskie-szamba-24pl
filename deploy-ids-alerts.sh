#!/bin/bash

set -e

RG="rg-medusashop-prod"
APPINSIGHTS_NAME="appi-medusashop-prod"
SUB_ID=$(az account show --query id -o tsv)

WORKSPACE_ID=$(az resource show \
  --resource-group $RG \
  --name $APPINSIGHTS_NAME \
  --resource-type "Microsoft.Insights/components" \
  --query "properties.WorkspaceResourceId" -o tsv)

echo "Deploying IDS/IPS alerts..."
echo "Workspace: $WORKSPACE_ID"
echo ""

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Insights/scheduledQueryRules/ids-sql-injection?api-version=2021-08-01" \
  --body "{
    \"location\": \"polandcentral\",
    \"properties\": {
      \"displayName\": \"IDS: SQL Injection Detection\",
      \"description\": \"Detects SQL injection attempts\",
      \"severity\": 2,
      \"enabled\": true,
      \"scopes\": [\"$WORKSPACE_ID\"],
      \"evaluationFrequency\": \"PT5M\",
      \"windowSize\": \"PT10M\",
      \"criteria\": {
        \"allOf\": [{
          \"query\": \"AppRequests | where TimeGenerated > ago(10m) | extend QueryString = tostring(parse_url(Url).[\\\"Query Parameters\\\"]) | where QueryString contains \\\"'\\\" or QueryString contains \\\"--\\\" or QueryString contains \\\"union\\\" or QueryString contains \\\"select\\\" | summarize count()\",
          \"timeAggregation\": \"Count\",
          \"operator\": \"GreaterThan\",
          \"threshold\": 3,
          \"failingPeriods\": {
            \"numberOfEvaluationPeriods\": 1,
            \"minFailingPeriodsToAlert\": 1
          }
        }]
      },
      \"autoMitigate\": false
    }
  }" && echo "✓ SQL Injection alert created" || echo "✗ SQL Injection alert failed"

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Insights/scheduledQueryRules/ids-admin-brute-force?api-version=2021-08-01" \
  --body "{
    \"location\": \"polandcentral\",
    \"properties\": {
      \"displayName\": \"IDS: Admin Brute Force\",
      \"description\": \"Detects brute force attacks on admin panel\",
      \"severity\": 2,
      \"enabled\": true,
      \"scopes\": [\"$WORKSPACE_ID\"],
      \"evaluationFrequency\": \"PT5M\",
      \"windowSize\": \"PT5M\",
      \"criteria\": {
        \"allOf\": [{
          \"query\": \"AppRequests | where TimeGenerated > ago(5m) | where Url contains \\\"/admin\\\" or Url contains \\\"/app\\\" | where ResultCode in (401, 403) | summarize FailedAttempts = count() | where FailedAttempts > 10\",
          \"timeAggregation\": \"Count\",
          \"operator\": \"GreaterThan\",
          \"threshold\": 0,
          \"failingPeriods\": {
            \"numberOfEvaluationPeriods\": 1,
            \"minFailingPeriodsToAlert\": 1
          }
        }]
      },
      \"autoMitigate\": false
    }
  }" && echo "✓ Admin Brute Force alert created" || echo "✗ Admin Brute Force alert failed"

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Insights/scheduledQueryRules/ids-credential-stuffing?api-version=2021-08-01" \
  --body "{
    \"location\": \"polandcentral\",
    \"properties\": {
      \"displayName\": \"IDS: Credential Stuffing\",
      \"description\": \"Detects credential stuffing attacks\",
      \"severity\": 2,
      \"enabled\": true,
      \"scopes\": [\"$WORKSPACE_ID\"],
      \"evaluationFrequency\": \"PT5M\",
      \"windowSize\": \"PT5M\",
      \"criteria\": {
        \"allOf\": [{
          \"query\": \"AppRequests | where TimeGenerated > ago(5m) | where Url contains \\\"/auth/login\\\" or Url contains \\\"/admin/auth\\\" | where ResultCode == 401 | summarize FailedLogins = count() | where FailedLogins > 10\",
          \"timeAggregation\": \"Count\",
          \"operator\": \"GreaterThan\",
          \"threshold\": 0,
          \"failingPeriods\": {
            \"numberOfEvaluationPeriods\": 1,
            \"minFailingPeriodsToAlert\": 1
          }
        }]
      },
      \"autoMitigate\": false
    }
  }" && echo "✓ Credential Stuffing alert created" || echo "✗ Credential Stuffing alert failed"

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Insights/scheduledQueryRules/ids-ddos-detection?api-version=2021-08-01" \
  --body "{
    \"location\": \"polandcentral\",
    \"properties\": {
      \"displayName\": \"IDS: DDoS Detection\",
      \"description\": \"Detects potential DDoS attacks\",
      \"severity\": 1,
      \"enabled\": true,
      \"scopes\": [\"$WORKSPACE_ID\"],
      \"evaluationFrequency\": \"PT1M\",
      \"windowSize\": \"PT1M\",
      \"criteria\": {
        \"allOf\": [{
          \"query\": \"AppRequests | where TimeGenerated > ago(1m) | summarize TotalRequests = count() | where TotalRequests > 1000\",
          \"timeAggregation\": \"Count\",
          \"operator\": \"GreaterThan\",
          \"threshold\": 0,
          \"failingPeriods\": {
            \"numberOfEvaluationPeriods\": 1,
            \"minFailingPeriodsToAlert\": 1
          }
        }]
      },
      \"autoMitigate\": false
    }
  }" && echo "✓ DDoS Detection alert created" || echo "✗ DDoS Detection alert failed"

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Insights/scheduledQueryRules/ids-session-hijacking?api-version=2021-08-01" \
  --body "{
    \"location\": \"polandcentral\",
    \"properties\": {
      \"displayName\": \"IDS: Session Hijacking\",
      \"description\": \"Detects session hijacking attempts\",
      \"severity\": 2,
      \"enabled\": true,
      \"scopes\": [\"$WORKSPACE_ID\"],
      \"evaluationFrequency\": \"PT5M\",
      \"windowSize\": \"PT10M\",
      \"criteria\": {
        \"allOf\": [{
          \"query\": \"AppRequests | where TimeGenerated > ago(10m) | where toint(ResultCode) >= 400 | summarize ErrorCount = count() | where ErrorCount > 50\",
          \"timeAggregation\": \"Count\",
          \"operator\": \"GreaterThan\",
          \"threshold\": 0,
          \"failingPeriods\": {
            \"numberOfEvaluationPeriods\": 1,
            \"minFailingPeriodsToAlert\": 1
          }
        }]
      },
      \"autoMitigate\": false
    }
  }" && echo "✓ Session Hijacking alert created" || echo "✗ Session Hijacking alert failed"

az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG/providers/Microsoft.Insights/scheduledQueryRules/ids-port-scanning?api-version=2021-08-01" \
  --body "{
    \"location\": \"polandcentral\",
    \"properties\": {
      \"displayName\": \"IDS: Port Scanning\",
      \"description\": \"Detects port scanning activity\",
      \"severity\": 3,
      \"enabled\": true,
      \"scopes\": [\"$WORKSPACE_ID\"],
      \"evaluationFrequency\": \"PT5M\",
      \"windowSize\": \"PT5M\",
      \"criteria\": {
        \"allOf\": [{
          \"query\": \"AppRequests | where TimeGenerated > ago(5m) | summarize DistinctUrls = dcount(Url), TotalRequests = count() | where DistinctUrls > 100 and TotalRequests > 200\",
          \"timeAggregation\": \"Count\",
          \"operator\": \"GreaterThan\",
          \"threshold\": 0,
          \"failingPeriods\": {
            \"numberOfEvaluationPeriods\": 1,
            \"minFailingPeriodsToAlert\": 1
          }
        }]
      },
      \"autoMitigate\": false
    }
  }" && echo "✓ Port Scanning alert created" || echo "✗ Port Scanning alert failed"


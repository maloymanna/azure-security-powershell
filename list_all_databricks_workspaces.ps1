# -------------------------------
# Script to export all Azure Databricks Workspaces
# -------------------------------
# Requirements:
#  - Azure PowerShell module (Az) installed
#  - User must be authenticated with sufficient permissions
# -------------------------------
# Output: CSV with following fields
#  - SubscriptionName
#  - ResourceGroupName
#  - WorkspaceName
#  - WorkspaceUrl

# -------------------------------
# PARAMETERS - set these in the script
# -------------------------------
 $tenantId = "Tenant ID"  # Set the Tenant ID

 $subscriptions = @("subscription_1", "subscription_2") # Set the subscriptions

$OutputFolder = ".\"  # Set  folder for logs and output, default is same folder as script
$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$OutputCsv = "$OutputFolder\databricks_workspaces_$Timestamp.csv"
# -------------------------------

# Create output folder if it doesn't exist
if (!(Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Initialize log file
$LogFile = "$OutputFolder\databricks_workspace_export_log_$Timestamp.txt"
"Starting Databricks workspace export at $(Get-Date)" | Tee-Object -FilePath $LogFile -Append

# Initialize results array and counter
$workspaceResults = @()
$count = 0

# -------------------------------
# CONNECT TO AZURE TENANT
# -------------------------------
try {
 "Connecting to Azure Tenant: $tenantId" | Tee-Object -FilePath $LogFile -Append
Connect-AzAccount -TenantId $tenantId -ErrorAction Stop
 "Successfully connected to Azure Tenant." | Tee-Object -FilePath $LogFile -Append
}
catch {
 "ERROR: Failed to connect to Azure Tenant. $_" | Tee-Object -FilePath $LogFile -Append
exit 1
}

# -------------------------------
# PROCESS EACH SUBSCRIPTION
# -------------------------------
foreach ($subscriptionId in $subscriptions) {
try {
 "Processing subscription: $subscriptionId" | Tee-Object -FilePath $LogFile -Append

# Set context to subscription
Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop

$subscriptionName = (Get-AzContext).Subscription.Name
     "Retrieving all Databricks workspaces in subscription: $subscriptionName ($subscriptionId)" | Tee-Object -FilePath $LogFile -Append

    # Get all Databricks workspaces in the subscription
	$workspaces = Get-AzResource -ResourceType "Microsoft.Databricks/workspaces"

    if ($null -eq $workspaces) {
         "No Databricks workspaces found in subscription: $subscriptionName" | Tee-Object -FilePath $LogFile -Append
    }
    else {
        foreach ($workspace in $workspaces) {
			$subscriptionId = $workspace.SubscriptionId
			$resourceGroup = $workspace.ResourceGroupName
			$workspaceName = $workspace.Name
			
			# Construct REST API path
			$apiPath = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Databricks/workspaces/$($workspaceName)?api-version=2024-05-01"
			
			# Call REST API to get full workspace details
			$response = Invoke-AzRestMethod -Method GET -Path $apiPath
			$json = $response.Content | ConvertFrom-Json
			
			# Parse JSON content and extract workspaceUrl
			$workspaceUrl = $json.properties.workspaceUrl
				
			$result = [PSCustomObject]@{
                SubscriptionName = $subscriptionName
                ResourceGroupName = $resourceGroup
                WorkspaceName    = $workspaceName
                WorkspaceUrl     = "https://$workspaceUrl"
            }
            $workspaceResults += $result
			$count += 1
			"$count. $($workspaceName) : https://$($workspaceUrl)" | Tee-Object -FilePath $LogFile -Append
        }
         "Found $($workspaces.Count) Databricks workspaces in subscription: $subscriptionName" | Tee-Object -FilePath $LogFile -Append
    }
}
catch {
     "ERROR: Failed to process subscription $subscriptionId. $_" | Tee-Object -FilePath $LogFile -Append
    continue
}

}

# -------------------------------
# EXPORT RESULTS TO CSV
# -------------------------------
if ($workspaceResults.Count -gt 0) {
try {
$workspaceResults | Export-Csv -Path $OutputCsv -NoTypeInformation -ErrorAction Stop
 "Successfully exported $($workspaceResults.Count) workspaces to $OutputCsv" | Tee-Object -FilePath $LogFile -Append
}
catch {
 "ERROR: Failed to export results to CSV. $_" | Tee-Object -FilePath $LogFile -Append
}
}
else {
 "No Databricks workspaces found in any subscriptions. No CSV file created." | Tee-Object -FilePath $LogFile -Append
}

 "Script execution completed." | Tee-Object -FilePath $LogFile -Append
# -------------------------------
# Script to export all Azure Databricks workspace groups, spns, group members and entitlements
# -------------------------------
# Requirements:
#  - Azure PowerShell module (Az) installed
#  - User must be authenticated with Databricks PAT
# Note: Script needs modification to use different PATs for different workspaces.
# -------------------------------
# TODO: 
#  - Modify script to use SPN without need of PAT
# -------------------------------
# Input: CSV with following fields, including header
#  - SubscriptionName
#  - ResourceGroupName
#  - WorkspaceName
#  - WorkspaceUrl
# -------------------------------
# Output: CSV with following fields
#  - SubscriptionName
#  - ResourceGroupName
#  - WorkspaceName
#  - WorkspaceUrl
#  - GroupName
#  - GroupId
#  - GroupMemberEmailorSPNname
#  - GroupMemberId
#  - Entitlements
#  - HighPrivilege [yes or no]
#  - Type [group or service principal]

# -------------------------------
# PARAMETERS - set these in the script
# -------------------------------
$bearerToken = "Replace with PAT"  #Bearer Token
$inputFile = "input.csv" # Input CSV containing list of Azure Databricks workspaces
$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$outputCsv = "databricks_groups_spns_entitlements_$Timestamp.csv"
# -------------------------------

# -------------------------------
# HEADERS
# -------------------------------
$headers = @{
    Authorization = "Bearer $bearerToken"
    "Content-Type" = "application/scim+json"
}

# -------------------------------
# READ INPUT FILE
# -------------------------------
# $workspaceList = Import-Csv -Path $inputFile -Header ("WorkspaceName", "WorkspaceUrl") # Use when no header
$workspaceList = Import-Csv -Path $inputFile  # Use when header exists

# -------------------------------
# COLLECT DATA ACROSS WORKSPACES
# -------------------------------
$results = @()

foreach ($workspace in $workspaceList) {
	$subName = $workspace.SubscriptionName
	$rgName = $workspace.ResourceGroupName
    $workspaceName = $workspace.WorkspaceName
    $workspaceUrl = $workspace.WorkspaceUrl

    # -------------------------------
    # GET GROUPS
    # -------------------------------
    $groupsUri = "$workspaceUrl/api/2.0/preview/scim/v2/Groups"
    $groupsResponse = Invoke-RestMethod -Method GET -Uri $groupsUri -Headers $headers
    $groups = $groupsResponse.Resources

    foreach ($group in $groups) {
        $groupName = $group.displayName
        $groupId = $group.id
        $entitlements = $group.entitlements | ForEach-Object { $_.value }
        $entitlementText = if ($entitlements) { $entitlements -join ", " } else { "None" }
        $highPrivilege = if ($entitlements -contains "allow-cluster-create") { "yes" } else { "no" }

        foreach ($member in $group.members) {
            $userId = $member.value
			$userEmail = $null
			try {
			    $userUri = "$workspaceUrl/api/2.0/preview/scim/v2/Users/$userId"
				$userResponse = Invoke-RestMethod -Method GET -Uri $userUri -Headers $headers
				$userEmail = $userResponse.userName
			}
			catch {
				continue # Skip if user not found - likely a service principal 
			}

            $results += [PSCustomObject]@{
				SubscriptionName		= $subName
				ResourceGroupName = $rgName
                WorkspaceName      = $workspaceName
                WorkspaceUrl       = $workspaceUrl
                GroupName          = $groupName
                GroupId            = $groupId
                GroupMemberEmailorSPNname  = $userEmail
                GroupMemberId     = $userId
                Entitlements        = $entitlementText
                HighPrivilege      = $highPrivilege
                Type                = "group"
            }
        }
    }

    # -------------------------------
    # GET SERVICE PRINCIPALS
    # -------------------------------
    $spUri = "$workspaceUrl/api/2.0/preview/scim/v2/ServicePrincipals"
    $spResponse = Invoke-RestMethod -Method GET -Uri $spUri -Headers $headers
    $servicePrincipals = $spResponse.Resources

    foreach ($sp in $servicePrincipals) {
        $spName = $sp.displayName
        $spId = $sp.id
        $entitlements = $sp.entitlements | ForEach-Object { $_.value }
        $entitlementText = if ($entitlements) { $entitlements -join ", " } else { "None" }
        $highPrivilege = if ($entitlements -contains "allow-cluster-create") { "yes" } else { "no" }

        $results += [PSCustomObject]@{
			SubscriptionName		= $subName
			ResourceGroupName = $rgName
            WorkspaceName      = $workspaceName
            WorkspaceUrl       = $workspaceUrl
            GroupName          = $groupName
            GroupId            = $groupId
            GroupMemberEmailorSPNname  = $spName
            GroupMemberId     = $spId
            Entitlements        = $entitlementText
            HighPrivilege      = $highPrivilege
            Type                = "service principal"
        }
    }
}

# -------------------------------
# EXPORT TO CSV
# -------------------------------
$results | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8

Write-Output "Databricks groups, spns, and entitlements saved to $outputCsv"

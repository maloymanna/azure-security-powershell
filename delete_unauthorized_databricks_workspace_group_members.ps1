# -------------------------------
# Script to remove unauthorized Azure Databricks workspaces' group members
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
$bearerToken = "Replace with PAT"  #Databricks PAT
$inputFile = "unauthorized_access.csv"
$outputCsv = "removal_log.csv"

# -------------------------------
# HEADERS
# -------------------------------
$headers = @{
    Authorization = "Bearer $bearerToken"
    "Content-Type" = "application/scim+json"
}

# -------------------------------
# READ FILTERED CSV AND REMOVE USERS FROM GROUPS
# -------------------------------
$rows = Import-Csv -Path $inputFile
$log = @()

foreach ($row in $rows) {
    if ($row.type -ne "group") {
        continue
    }

    $workspaceUrl = $row.workspace_url
    $groupName    = $row.group_name
    $userId       = $row.group_member_ID

    # Lookup group ID by name
    $groupLookupUri = "$workspaceUrl/api/2.0/preview/scim/v2/Groups?filter=displayName eq `"$groupName`""
    try {
        $groupResponse = Invoke-RestMethod -Method GET -Uri $groupLookupUri -Headers $headers
        $groupId = $groupResponse.Resources[0].id
    } catch {
        Write-Warning "Group '$groupName' not found in $workspaceUrl"
        $log += [PSCustomObject]@{
            workspace_url = $workspaceUrl
            group_name    = $groupName
            user_id       = $userId
            status        = "Group not found"
        }
        continue
    }

    # Prepare PATCH payload to remove user from group
    $patchUri = "$workspaceUrl/api/2.0/preview/scim/v2/Groups/$groupId"
    $payload = @{
        schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
        Operations = @(@{
            op   = "remove"
            path = "members[value eq `"$userId`"]"
        })
    }

    try {
        Invoke-RestMethod -Method PATCH -Uri $patchUri -Headers $headers -Body ($payload | ConvertTo-Json -Depth 3)
        Write-Output "Removed user $userId from group '$groupName' in workspace $workspaceUrl"
        $log += [PSCustomObject]@{
            workspace_url = $workspaceUrl
            group_name    = $groupName
            user_id       = $userId
            status        = "Removed"
        }
    } catch {
        Write-Warning "Failed to remove user $userId from group '$groupName' in $workspaceUrl"
        $log += [PSCustomObject]@{
            workspace_url = $workspaceUrl
            group_name    = $groupName
            user_id       = $userId
            status        = "Failed"
        }
    }
}

# -------------------------------
# EXPORT LOG
# -------------------------------
$log | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Output "Removal log saved to $outputCsv"

# Find SPNs with Owner role on Resource Groups
function Get-HighRiskSpnAssignments {
    $assignments = Get-AzRoleAssignment | Where-Object {
        $_.RoleDefinitionName -eq "Owner" -and
        $_.ObjectType -eq "ServicePrincipal" -and
        $_.Scope -like "*/resourceGroups/*"
    }

    # Ensure we return an array (empty array instead of $null)
    return ,$assignments
}

function Main {
    # Connect to Azure
    Connect-AzAccount

    # Call function to get high-risk SPNs
    $highRiskAssignments = Get-HighRiskSpnAssignments

    # Process the result
    if ($highRiskAssignments.Count -gt 0) {
        Write-Warning "Found $($highRiskAssignments.Count) SPNs with Owner role on Resource Groups:"
        $highRiskAssignments | Select-Object DisplayName, RoleDefinitionName, Scope, ObjectId | Format-Table -AutoSize
    } else {
        Write-Host "No SPNs found with Owner role on Resource Groups." -ForegroundColor Green
    }
}

# Only run when the script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
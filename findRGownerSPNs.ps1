# Find SPNs with Owner role on Resource Groups
Connect-AzAccount

$highRiskAssignments = Get-AzRoleAssignment | Where-Object {
    $_.RoleDefinitionName -eq "Owner" -and
    $_.ObjectType -eq "ServicePrincipal" -and
    $_.Scope -like "*/resourceGroups/*"
}

if ($highRiskAssignments.Count -gt 0) {
    Write-Warning "Found $($highRiskAssignments.Count) SPNs with Owner role on Resource Groups:"
    $highRiskAssignments | Select-Object DisplayName, RoleDefinitionName, Scope, ObjectId | Format-Table -AutoSize
} else {
    Write-Host "No SPNs found with Owner role on Resource Groups." -ForegroundColor Green
}

# Also check for secrets expiring in > 90 days
$longLivedSecrets = foreach ($sp in Get-AzADServicePrincipal) {
    $creds = Get-AzADSpCredential -ObjectId $sp.Id -ErrorAction SilentlyContinue
    foreach ($cred in $creds) {
        if ($cred.EndDate - (Get-Date) -gt (New-TimeSpan -Days 90)) {
            [PSCustomObject]@{
                SPNDisplayName = $sp.DisplayName
                KeyId          = $cred.KeyId
                EndDate        = $cred.EndDate
                DaysUntilExpiry = ($cred.EndDate - (Get-Date)).Days
            }
        }
    }
}

if ($longLivedSecrets.Count -gt 0) {
    Write-Warning "Found $($longLivedSecrets.Count) SPN secrets with >90 days validity:"
    $longLivedSecrets | Sort-Object DaysUntilExpiry -Descending | Format-Table -AutoSize
}
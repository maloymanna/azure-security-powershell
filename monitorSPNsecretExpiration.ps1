# Connect to Azure
Connect-AzAccount -TenantId "<Tenant_ID>" -SubscriptionId "<Subscription_ID>"

# Function to check service principal secret expirations
function Get-ServicePrincipalSecretExpirations {
    param (
        [int]$DaysThreshold = 30
    )
    
    try {
        # Get all service principals in the tenant
        $servicePrincipals = Get-AzADServicePrincipal
        
        $expiringSecrets = @()
        $currentDate = Get-Date
        
        foreach ($sp in $servicePrincipals) {
            # Get credentials for the service principal
            $credentials = Get-AzADServicePrincipalCredential -ObjectId $sp.Id
            
            foreach ($cred in $credentials) {
                # Check if the credential is a secret (not a certificate)
                if ($cred.Type -eq "Password") {
                    $endDate = $cred.EndDate
                    
                    # Calculate days until expiration
                    $daysUntilExpiration = ($endDate - $currentDate).Days
                    
                    # If the secret is expiring within the threshold, add to the list
                    if ($daysUntilExpiration -le $DaysThreshold -and $daysUntilExpiration -ge 0) {
                        $expiringSecrets += [PSCustomObject]@{
                            ServicePrincipalName = $sp.DisplayName
                            ServicePrincipalId = $sp.Id
                            SecretKeyId = $cred.KeyId
                            EndDate = $endDate
                            DaysUntilExpiration = $daysUntilExpiration
                        }
                    }
                }
            }
        }
        
        # Display results
        if ($expiringSecrets.Count -gt 0) {
            Write-Warning "Found $($expiringSecrets.Count) service principal secrets expiring within the next $DaysThreshold days:"
            $expiringSecrets | Format-Table -AutoSize
        }
        else {
            Write-Output "No service principal secrets found expiring within the next $DaysThreshold days."
        }
        
        return $expiringSecrets
    }
    catch {
        Write-Error "Failed to check service principal secret expirations: $_"
        return $null
    }
}

# Example usage
# Get-ServicePrincipalSecretExpirations -DaysThreshold 30
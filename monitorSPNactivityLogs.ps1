# Connect to Azure
Connect-AzAccount -TenantId "<Tenant_ID>" -SubscriptionId "<Subscription_ID>"

# Function to set up comprehensive monitoring for service principal secret access
function Setup-ServicePrincipalSecretMonitoring {
    param (
        [string]$LogAnalyticsWorkspaceName = "spn-monitoring-workspace",
        [string]$ResourceGroupName = "monitoring-rg",
        [string]$Location = "East US"
    )
    
    try {
        # Create or get Log Analytics workspace
        $workspace = Get-AzOperationalInsightsWorkspace -Name $LogAnalyticsWorkspaceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -eq $workspace) {
            Write-Output "Creating Log Analytics workspace: $LogAnalyticsWorkspaceName"
            $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $LogAnalyticsWorkspaceName -Location $Location -Sku pergb2018
        }
        else {
            Write-Output "Using existing Log Analytics workspace: $LogAnalyticsWorkspaceName"
        }
        
        # Enable diagnostic settings for Key Vault (if secrets are stored there)
        $keyVaults = Get-AzKeyVault
        foreach ($kv in $keyVaults) {
            $existingDiag = Get-AzDiagnosticSetting -ResourceId $kv.ResourceId -Name "KeyVaultMonitoring" -ErrorAction SilentlyContinue
            if ($null -eq $existingDiag) {
                Write-Output "Enabling diagnostic settings for Key Vault: $($kv.Name)"
                $params = @{
                    Name = "KeyVaultMonitoring"
                    ResourceId = $kv.ResourceId
                    WorkspaceId = $workspace.ResourceId
                    Enabled = $true
                    Category = @[
                        "AuditEvent"
                    ]
                    MetricEnabled = $false
                    LogsEnabled = $true
                    RetentionEnabled = $true
                    RetentionInDays = 90
                }
                Set-AzDiagnosticSetting @params
            }
        }
        
        # Enable diagnostic settings for service principals
        $servicePrincipals = Get-AzADServicePrincipal
        foreach ($sp in $servicePrincipals) {
            $existingDiag = Get-AzDiagnosticSetting -ResourceId $sp.Id -Name "ServicePrincipalMonitoring" -ErrorAction SilentlyContinue
            if ($null -eq $existingDiag) {
                Write-Output "Enabling diagnostic settings for Service Principal: $($sp.DisplayName)"
                $params = @{
                    Name = "ServicePrincipalMonitoring"
                    ResourceId = $sp.Id
                    WorkspaceId = $workspace.ResourceId
                    Enabled = $true
                    Category = @[
                        "SignInLogs"
                        "AuditLogs"
                        "NonInteractiveUserSignInLogs"
                    ]
                    MetricEnabled = $false
                    LogsEnabled = $true
                    RetentionEnabled = $true
                    RetentionInDays = 90
                }
                Set-AzDiagnosticSetting @params
            }
        }
        
        # Create alert rules
        Create-SecretAccessAlertRules -WorkspaceId $workspace.ResourceId -ResourceGroupName $workspace.ResourceGroupName
        
        Write-Output "Monitoring setup completed successfully"
        return $workspace
    }
    catch {
        Write-Error "Failed to set up monitoring: $_"
        return $null
    }
}

# Function to create alert rules for secret access
function Create-SecretAccessAlertRules {
    param (
        [string]$WorkspaceId,
        [string]$ResourceGroupName
    )
    
    # Alert for Key Vault secret access after business hours
    $afterHoursParams = @{
        Name = "KeyVaultSecretAccessAfterHours"
        ResourceGroupName = $ResourceGroupName
        Scope = "/subscriptions/<Subscription_ID>"
        Description = "Alert on Key Vault secret access outside business hours (8AM-6PM, Mon-Fri)"
        Severity = "2"
        TargetResourceType = "Microsoft.KeyVault/vaults"
        Condition = @{
            MetricName = "SecretAccessCount"
            Operator = "GreaterThan"
            Threshold = "0"
            TimeAggregationOperator = "Total"
            TimeGrain = "PT1H"
            Filter = "datetimehour(hourOfDay()) < 8 or datetimehour(hourOfDay()) > 18 or (dayofweek() > 5)"
        }
        Action = @{
            ActionGroup = @()
        }
        Enabled = $true
        Location = "East US"
    }
    
    New-AzMetricAlertRuleV2 @afterHoursParams
    
    # Alert for multiple failed secret access attempts
    $failedAttemptsParams = @{
        Name = "KeyVaultSecretAccessFailedAttempts"
        ResourceGroupName = $ResourceGroupName
        Scope = "/subscriptions/<Subscription_ID>"
        Description = "Alert on multiple failed Key Vault secret access attempts"
        Severity = "1"
        TargetResourceType = "Microsoft.KeyVault/vaults"
        Condition = @{
            MetricName = "SecretAccessFailedCount"
            Operator = "GreaterThan"
            Threshold = "5"
            TimeAggregationOperator = "Total"
            TimeGrain = "PT1H"
        }
        Action = @{
            ActionGroup = @()
        }
        Enabled = $true
        Location = "East US"
    }
    
    New-AzMetricAlertRuleV2 @failedAttemptsParams
    
    Write-Output "Created alert rules for Key Vault secret access monitoring"
}

# Example usage
# $workspace = Setup-ServicePrincipalSecretMonitoring
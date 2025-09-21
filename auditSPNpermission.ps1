# Connect to Azure
Connect-AzAccount -TenantId "<Tenant_ID>" -SubscriptionId "<Subscription_ID>"

# Function to audit service principal permissions
function Get-ServicePrincipalPermissions {
    param (
        [string]$ServicePrincipalId
    )
    
    try {
        # Get the service principal
        $sp = Get-AzADServicePrincipal -ObjectId $ServicePrincipalId
        
        if ($null -eq $sp) {
            Write-Error "Service principal with ID $ServicePrincipalId not found."
            return
        }
        
        Write-Output "Auditing permissions for service principal: $($sp.DisplayName)"
        
        # Get role assignments at the subscription level
        $subscriptionRoleAssignments = Get-AzRoleAssignment -ObjectId $sp.Id
        if ($subscriptionRoleAssignments) {
            Write-Output "Subscription-level role assignments:"
            $subscriptionRoleAssignments | Format-Table -Property DisplayName, RoleDefinitionName, Scope, ObjectType
        }
        else {
            Write-Output "No subscription-level role assignments found."
        }
        
        # Get role assignments at the resource group level
        $resourceGroups = Get-AzResourceGroup
        foreach ($rg in $resourceGroups) {
            $rgRoleAssignments = Get-AzRoleAssignment -ObjectId $sp.Id -ResourceGroupName $rg.ResourceGroupName
            if ($rgRoleAssignments) {
                Write-Output "Resource group $($rg.ResourceGroupName) role assignments:"
                $rgRoleAssignments | Format-Table -Property DisplayName, RoleDefinitionName, Scope, ObjectType
            }
        }
        
        # Get role assignments at the resource level
        $resources = Get-AzResource
        foreach ($resource in $resources) {
            $resourceRoleAssignments = Get-AzRoleAssignment -ObjectId $sp.Id -ResourceGroupName $resource.ResourceGroupName -ResourceName $resource.Name -ResourceType $resource.ResourceType
            if ($resourceRoleAssignments) {
                Write-Output "Resource $($resource.Name) role assignments:"
                $resourceRoleAssignments | Format-Table -Property DisplayName, RoleDefinitionName, Scope, ObjectType
            }
        }
    }
    catch {
        Write-Error "Failed to audit service principal permissions: $_"
    }
}

# Example usage
# Get-ServicePrincipalPermissions -ServicePrincipalId "<Service_Principal_Object_ID>"
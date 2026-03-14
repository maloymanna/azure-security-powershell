BeforeAll {
    . "$PSScriptRoot/../findRGownerSPNs.ps1"
}

Describe "SPN Owner role detection" {
    It "Detects SPN with Owner role on Resource Group" {
        Mock Get-AzRoleAssignment {
            @(
                [PSCustomObject]@{
                    RoleDefinitionName = "Owner"
                    ObjectType = "ServicePrincipal"
                    Scope = "/subscriptions/123/resourceGroups/testRG"
                }
            )
        }
        $result = Get-HighRiskSpnAssignments
        $result.Count | Should -Be 1
    }

    It "Ignores assignments that are not Owner role" {
        Mock Get-AzRoleAssignment {
            @(
                [PSCustomObject]@{
                    RoleDefinitionName = "Reader"
                    ObjectType = "ServicePrincipal"
                    Scope = "/subscriptions/123/resourceGroups/testRG"
                }
            )
        }
        $result = Get-HighRiskSpnAssignments
        $result | Should -BeNullOrEmpty
    }

    It "Ignores assignments that are not Service Principals" {
        Mock Get-AzRoleAssignment {
            @(
                [PSCustomObject]@{
                    RoleDefinitionName = "Owner"
                    ObjectType = "User"
                    Scope = "/subscriptions/123/resourceGroups/testRG"
                }
            )
        }
        $result = Get-HighRiskSpnAssignments
        $result | Should -BeNullOrEmpty
    }
}

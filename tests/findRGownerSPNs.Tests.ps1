BeforeAll {
    . "$PSScriptRoot/findRGownerSPNs.ps1"
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

Describe "Long lived secret detection" {
    It "Finds secrets valid for more than 90 days" {
        Mock Get-AzADServicePrincipal {
            @(
                [PSCustomObject]@{
                    Id = "sp1"
                    DisplayName = "TestSP"
                }
            )
        }
        Mock Get-AzADSpCredential {
            @(
                [PSCustomObject]@{
                    KeyId = "secret1"
                    EndDate = (Get-Date).AddDays(120)
                }
            )
        }
        $result = Get-LongLivedSecrets
        $result.Count | Should -Be 1
        $result.SPNDisplayName | Should -Be "TestSP"
    }

    It "Ignores secrets shorter than 90 days" {
        Mock Get-AzADServicePrincipal {
            @(
                [PSCustomObject]@{
                    Id = "sp1"
                    DisplayName = "TestSP"
                }
            )
        }
        Mock Get-AzADSpCredential {
            @(
                [PSCustomObject]@{
                    KeyId = "secret1"
                    EndDate = (Get-Date).AddDays(30)
                }
            )
        }
        $result = Get-LongLivedSecrets
        $result | Should -BeNullOrEmpty
    }
}

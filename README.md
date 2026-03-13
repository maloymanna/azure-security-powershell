# PowerShell scripts for Azure security monitoring and oversight  
![CI](https://github.com/maloymanna/azure-security-powershell/actions/workflows/ci.yml/badge.svg)  [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=maloymanna_azure-security-powershell&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=maloymanna_azure-security-powershell)

1. List all role assignments for a user access audit
2. [List all Azure Databricks workspaces](../main/list_all_databricks_workspaces.ps1)
3. [List all Azure Databricks workspaces, groups, service principals, group members, group entitlements](../main/list_all_databricks_workspaces_groups_spns_entitlements.ps1)
4. [Delete unauthorized Azure Databricks workspaces' group members](../main/delete_unauthorized_databricks_workspace_group_members.ps1)

## Service Principals (SPN)
5. [Find Azure SPNs with owner role on resource groups](../main/findRGownerSPNs.ps1)
6. [Audit Azure Service Principal permissions](../main/auditSPNpermission.ps1)
7. [Monitor Azure service principal secret expiration for specified future duration](../main/monitorSPNsecretExpiration.ps1)
8. [Monitor Azure SPN activities for secret access](../main/monitorSPNactivityLogs.ps1)

## Azure DevOps
1. [Get list of Azure DevOps pipelines in a project](/getProjectPipelines.ps1) - Update myorg, myproj and PAT with real values before running the script.
2. [Get list of Azure DevOps folders in a project](/getAzDevOpsFolders.ps1) - Gets both Build/YAML and Classic Release folders exported to a CSV.

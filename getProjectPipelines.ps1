$org = "myorg"
$project = "myproject"
# Update with Personal Access Token
$pat = "PAT"

# Base64 encode the PAT for authentication
$token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$headers = @{Authorization = "Basic $token"}

# API URL for Pipelines
$url = "https://dev.azure.com/$org/$project/_apis/pipelines?api-version=7.1"

# Execute Request
$response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

# Output to console and CSV
$pipelineList = $response.value | Select-Object id, name, folder
$pipelineList | Format-Table
$pipelineList | Export-Csv -Path "./AzurePipelinesList.csv" -NoTypeInformation

Write-Host "Success! List saved to AzurePipelinesList.csv" -ForegroundColor Green
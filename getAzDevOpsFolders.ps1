# This script gets the Azure DevOps folders for a project in an org

# Configuration
$org = "myorg"
$project = "myproject"
$pat = "YOUR_PAT_HERE"
$csvPath = "./DevOpsFoldersExport_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

# Authentication
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    Accept        = "application/json"
}

$results = @()

function Get-DevOpsFolders($url) {
    try {
        Write-Host "Fetching $type folders..." -ForegroundColor Gray
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop
        return $response.value
    } catch {
        Write-Host "FAILED to fetch from $url. Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# 1. Build/YAML Folders
$buildFolderUrl = "https://dev.azure.com/$org/$project/_apis/build/folders?api-version=7.1-preview.2"

# 2. Release Folders 
$releaseFolderUrl = "https://vsrm.dev.azure.com/$org/$project/_apis/release/folders?api-version=7.1-preview.2"

# Fetch data
$buildFolders = Get-DevOpsFolders -url $buildFolderUrl
$releaseFolders = Get-DevOpsFolders -url $releaseFolderUrl

# Process Results
if ($null -ne $buildFolders) {
    foreach ($f in $buildFolders) {
        $results += [PSCustomObject]@{ Type = "Build/YAML"; Path = $f.path; CreatedBy = $f.createdBy.displayName }
    }
}
if ($null -ne $releaseFolders) {
    foreach ($f in $releaseFolders) {
        $results += [PSCustomObject]@{ Type = "Classic Release"; Path = $f.path; CreatedBy = $f.createdBy.displayName }
    }
}

# Export to CSV
if ($results.Count -gt 0) {
    $results | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "`nSuccess! Found $($results.Count) total folders. Saved to: $csvPath" -ForegroundColor Green
    $results | Format-Table -AutoSize
}
$ErrorActionPreference = "Stop"

$projectPath = ".\HealthcareHub.Api\HealthcareHub.Api.csproj"
$publishPath = ".\publish\api-linux"
$zipPath = ".\publish\HealthcareHub.Api-linux.zip"

$sqlClientRuntimeDll =
    "$env:USERPROFILE\.nuget\packages\microsoft.data.sqlclient\7.0.3\runtimes\unix\lib\net9.0\Microsoft.Data.SqlClient.dll"

Write-Host "Publishing HealthcareHub API for linux-x64..."

Remove-Item $publishPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

dotnet publish $projectPath `
    -c Release `
    -r linux-x64 `
    --self-contained false `
    -o $publishPath

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed."
}

if (-not (Test-Path $sqlClientRuntimeDll)) {
    throw "SqlClient Unix runtime DLL was not found: $sqlClientRuntimeDll"
}

Write-Host "Applying Microsoft.Data.SqlClient Linux runtime workaround..."

Copy-Item `
    $sqlClientRuntimeDll `
    "$publishPath\Microsoft.Data.SqlClient.dll" `
    -Force

$dll =
    Get-Item "$publishPath\Microsoft.Data.SqlClient.dll"

Write-Host "SqlClient DLL size: $($dll.Length) bytes"

Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.IO.Compression.ZipFile]::CreateFromDirectory(
    (Resolve-Path $publishPath).Path,
    (Join-Path (Resolve-Path ".\publish").Path "HealthcareHub.Api-linux.zip"),
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

Write-Host ""
Write-Host "Publish package ready:"
Write-Host $zipPath
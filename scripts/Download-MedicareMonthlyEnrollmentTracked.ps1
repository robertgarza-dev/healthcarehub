[CmdletBinding()]
param (
    [string]$OutputDirectory = ".\data\source\medicare-monthly-enrollment",

    [string]$SqlServer = "localhost,57064",

    [string]$Database = "HealthcareHub",

    [int]$DataSourceId = 1
)

$ErrorActionPreference = "Stop"

$CatalogUrl = "https://data.cms.gov/data.json"
$DatasetTitle = "Medicare Monthly Enrollment"

Write-Host "HealthcareHub - Medicare Monthly Enrollment"
Write-Host "Reading CMS catalog..."

$catalog = Invoke-RestMethod `
    -Uri $CatalogUrl `
    -Method Get

$dataset = $catalog.dataset |
    Where-Object { $_.title -eq $DatasetTitle } |
    Select-Object -First 1

if (-not $dataset) {
    throw "Dataset '$DatasetTitle' was not found in the CMS catalog."
}

$csvDistributions = @(
    $dataset.distribution |
        Where-Object {
            $_.mediaType -eq "text/csv" -and
            -not [string]::IsNullOrWhiteSpace($_.downloadURL)
        }
)

if ($csvDistributions.Count -eq 0) {
    throw "No CSV distribution was found for '$DatasetTitle'."
}

$latestCsv = $csvDistributions[0]

$downloadUrl = $latestCsv.downloadURL
$temporal = $latestCsv.temporal
$modified = $latestCsv.modified

Write-Host ""
Write-Host "Latest CMS distribution found:"
Write-Host "  Temporal:     $temporal"
Write-Host "  Modified:     $modified"
Write-Host "  Download URL: $downloadUrl"

if (-not (Test-Path $OutputDirectory)) {
    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force |
        Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$outputFile = Join-Path `
    $OutputDirectory `
    "Medicare_Monthly_Enrollment_$timestamp.csv"

Write-Host ""
Write-Host "Downloading..."
Write-Host "Destination: $outputFile"

Invoke-WebRequest `
    -Uri $downloadUrl `
    -OutFile $outputFile

$file = Get-Item $outputFile

$hash = Get-FileHash `
    -Path $outputFile `
    -Algorithm SHA256

$sha256 = $hash.Hash

Write-Host ""
Write-Host "Download complete."
Write-Host "  File:   $($file.Name)"
Write-Host "  Size:   $($file.Length)"
Write-Host "  SHA256: $sha256"

# Parse reporting period.
$reportingPeriodStart = $null
$reportingPeriodEnd = $null

if ($temporal -match '^(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})$') {
    $reportingPeriodStart = $Matches[1]
    $reportingPeriodEnd = $Matches[2]
}

# Build SQL connection.
$connectionString =
    "Server=$SqlServer;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

try {
    $connection.Open()

    # Check whether this exact file hash is already known.
    $checkCommand = $connection.CreateCommand()
    $checkCommand.CommandText = @"
SELECT
    SourceFileId,
    FileName,
    DownloadedUtc,
    IsProcessed,
    ProcessedUtc
FROM ops.SourceFile
WHERE DataSourceId = @DataSourceId
  AND Sha256 = @Sha256;
"@

    $null = $checkCommand.Parameters.Add(
        "@DataSourceId",
        [System.Data.SqlDbType]::Int
    )
    $checkCommand.Parameters["@DataSourceId"].Value = $DataSourceId

    $null = $checkCommand.Parameters.Add(
        "@Sha256",
        [System.Data.SqlDbType]::Char,
        64
    )
    $checkCommand.Parameters["@Sha256"].Value = $sha256

    $reader = $checkCommand.ExecuteReader()

    if ($reader.Read()) {
        $existingSourceFileId = $reader["SourceFileId"]
        $existingFileName = $reader["FileName"]
        $existingDownloadedUtc = $reader["DownloadedUtc"]
        $existingIsProcessed = $reader["IsProcessed"]

        $reader.Close()

        Write-Host ""
        Write-Host "This exact CMS file is already registered."
        Write-Host "  SourceFileId: $existingSourceFileId"
        Write-Host "  FileName:     $existingFileName"
        Write-Host "  Downloaded:   $existingDownloadedUtc"
        Write-Host "  Processed:    $existingIsProcessed"

        Write-Host ""
        Write-Host "Removing duplicate local download..."

        Remove-Item `
            -Path $outputFile `
            -Force

        [PSCustomObject]@{
            IsNewFile       = $false
            SourceFileId    = $existingSourceFileId
            DatasetTitle    = $dataset.title
            Temporal        = $temporal
            Modified        = $modified
            DownloadUrl     = $downloadUrl
            Sha256          = $sha256
        }

        return
    }

    $reader.Close()

    # Insert new source file record.
    $insertCommand = $connection.CreateCommand()

    $insertCommand.CommandText = @"
INSERT INTO ops.SourceFile
(
    DataSourceId,
    FileName,
    DownloadUrl,
    ReportingPeriodStart,
    ReportingPeriodEnd,
    SourceModifiedDate,
    FileSizeBytes,
    Sha256
)
OUTPUT INSERTED.SourceFileId
VALUES
(
    @DataSourceId,
    @FileName,
    @DownloadUrl,
    @ReportingPeriodStart,
    @ReportingPeriodEnd,
    @SourceModifiedDate,
    @FileSizeBytes,
    @Sha256
);
"@

    $null = $insertCommand.Parameters.Add(
        "@DataSourceId",
        [System.Data.SqlDbType]::Int
    )
    $insertCommand.Parameters["@DataSourceId"].Value = $DataSourceId

    $null = $insertCommand.Parameters.Add(
        "@FileName",
        [System.Data.SqlDbType]::NVarChar,
        260
    )
    $insertCommand.Parameters["@FileName"].Value = $file.Name

    $null = $insertCommand.Parameters.Add(
        "@DownloadUrl",
        [System.Data.SqlDbType]::NVarChar,
        1000
    )
    $insertCommand.Parameters["@DownloadUrl"].Value = $downloadUrl

    $null = $insertCommand.Parameters.Add(
        "@ReportingPeriodStart",
        [System.Data.SqlDbType]::Date
    )

    if ($reportingPeriodStart) {
        $insertCommand.Parameters["@ReportingPeriodStart"].Value =
            [DateTime]::Parse($reportingPeriodStart)
    }
    else {
        $insertCommand.Parameters["@ReportingPeriodStart"].Value =
            [DBNull]::Value
    }

    $null = $insertCommand.Parameters.Add(
        "@ReportingPeriodEnd",
        [System.Data.SqlDbType]::Date
    )

    if ($reportingPeriodEnd) {
        $insertCommand.Parameters["@ReportingPeriodEnd"].Value =
            [DateTime]::Parse($reportingPeriodEnd)
    }
    else {
        $insertCommand.Parameters["@ReportingPeriodEnd"].Value =
            [DBNull]::Value
    }

    $null = $insertCommand.Parameters.Add(
        "@SourceModifiedDate",
        [System.Data.SqlDbType]::Date
    )

    if ($modified) {
        $insertCommand.Parameters["@SourceModifiedDate"].Value =
            [DateTime]::Parse($modified)
    }
    else {
        $insertCommand.Parameters["@SourceModifiedDate"].Value =
            [DBNull]::Value
    }

    $null = $insertCommand.Parameters.Add(
        "@FileSizeBytes",
        [System.Data.SqlDbType]::BigInt
    )
    $insertCommand.Parameters["@FileSizeBytes"].Value = $file.Length

    $null = $insertCommand.Parameters.Add(
        "@Sha256",
        [System.Data.SqlDbType]::Char,
        64
    )
    $insertCommand.Parameters["@Sha256"].Value = $sha256

    $sourceFileId = $insertCommand.ExecuteScalar()

    Write-Host ""
    Write-Host "New source file registered."
    Write-Host "  SourceFileId: $sourceFileId"

    [PSCustomObject]@{
        IsNewFile           = $true
        SourceFileId        = $sourceFileId
        DatasetTitle        = $dataset.title
        Temporal            = $temporal
        Modified            = $modified
        DownloadUrl         = $downloadUrl
        FileName            = $file.Name
        FilePath            = $file.FullName
        FileSizeBytes       = $file.Length
        Sha256              = $sha256
    }
}
finally {
    if ($connection.State -eq "Open") {
        $connection.Close()
    }

    $connection.Dispose()
}
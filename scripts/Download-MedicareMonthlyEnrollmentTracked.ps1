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

# ------------------------------------------------------------
# Discover latest CMS distribution
# ------------------------------------------------------------

$catalog = Invoke-RestMethod `
    -Uri $CatalogUrl `
    -Method Get

$dataset = $catalog.dataset |
    Where-Object { 
        $_.title -like "*Medicare Monthly Enrollment*"
    } |
    Select-Object -First 1

if (-not $dataset) {
    Write-Host ""
    Write-Host "Possible CMS enrollment datasets:"

    $catalog.dataset | 
        Where-Object {
            $_.title -match "Medicare|Enrollment"
        } |
        Select-Object -First 25 title, landingPage |
        Format-Table -AutoSize

    throw "Dataset '$DatasetTitle' was not found in CMS catalog"
}    

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

# ------------------------------------------------------------
# Parse CMS reporting period
# ------------------------------------------------------------

$reportingPeriodStart = $null
$reportingPeriodEnd = $null

# CMS has represented temporal metadata in more than one shape.
# Support both the older string format:
#   2026-05-01/2026-05-31
#
# and the newer PeriodOfTime object:
#   @{ type=PeriodOfTime; startDate=2026-06-01; endDate=2026-06-30 }

if ($temporal -is [string]) {

    if ($temporal -match '^(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})$') {
        $reportingPeriodStart = $Matches[1]
        $reportingPeriodEnd = $Matches[2]
    }
}
elseif ($null -ne $temporal) {

    # Some CMS catalog entries expose temporal as an array.
    $temporalItem = @($temporal)[0]

    if ($temporalItem.PSObject.Properties.Name -contains "startDate") {
        $reportingPeriodStart = [string]$temporalItem.startDate
    }

    if ($temporalItem.PSObject.Properties.Name -contains "endDate") {
        $reportingPeriodEnd = [string]$temporalItem.endDate
    }
}

Write-Host ""
Write-Host "Parsed reporting period:"
Write-Host "  Start: $reportingPeriodStart"
Write-Host "  End:   $reportingPeriodEnd"


# ------------------------------------------------------------
# Make sure download folder exists
# ------------------------------------------------------------

if (-not (Test-Path $OutputDirectory)) {
    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force |
        Out-Null
}

# ------------------------------------------------------------
# Connect to HealthcareHub
# ------------------------------------------------------------

$connectionString =
    "Server=$SqlServer;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

try {
    $connection.Open()

    # --------------------------------------------------------
    # Metadata-first check
    #
    # If CMS URL + reporting period + modified date are all
    # already registered, there is no reason to download the
    # 200+ MB file again.
    # --------------------------------------------------------

    $metadataCommand = $connection.CreateCommand()

    $metadataCommand.CommandText = @"
SELECT TOP (1)
    SourceFileId,
    FileName,
    DownloadedUtc,
    FileSizeBytes,
    Sha256,
    IsProcessed,
    ProcessedUtc
FROM ops.SourceFile
WHERE DataSourceId = @DataSourceId
  AND DownloadUrl = @DownloadUrl
  AND ISNULL(ReportingPeriodStart, '19000101')
      = ISNULL(@ReportingPeriodStart, '19000101')
  AND ISNULL(ReportingPeriodEnd, '19000101')
      = ISNULL(@ReportingPeriodEnd, '19000101')
  AND ISNULL(SourceModifiedDate, '19000101')
      = ISNULL(@SourceModifiedDate, '19000101')
ORDER BY SourceFileId DESC;
"@

    $null = $metadataCommand.Parameters.Add(
        "@DataSourceId",
        [System.Data.SqlDbType]::Int
    )
    $metadataCommand.Parameters["@DataSourceId"].Value = $DataSourceId

    $null = $metadataCommand.Parameters.Add(
        "@DownloadUrl",
        [System.Data.SqlDbType]::NVarChar,
        1000
    )
    $metadataCommand.Parameters["@DownloadUrl"].Value = $downloadUrl

    $null = $metadataCommand.Parameters.Add(
        "@ReportingPeriodStart",
        [System.Data.SqlDbType]::Date
    )

    if ($reportingPeriodStart) {
        $metadataCommand.Parameters["@ReportingPeriodStart"].Value =
            [DateTime]::Parse($reportingPeriodStart)
    }
    else {
        $metadataCommand.Parameters["@ReportingPeriodStart"].Value =
            [DBNull]::Value
    }

    $null = $metadataCommand.Parameters.Add(
        "@ReportingPeriodEnd",
        [System.Data.SqlDbType]::Date
    )

    if ($reportingPeriodEnd) {
        $metadataCommand.Parameters["@ReportingPeriodEnd"].Value =
            [DateTime]::Parse($reportingPeriodEnd)
    }
    else {
        $metadataCommand.Parameters["@ReportingPeriodEnd"].Value =
            [DBNull]::Value
    }

    $null = $metadataCommand.Parameters.Add(
        "@SourceModifiedDate",
        [System.Data.SqlDbType]::Date
    )

    if ($modified) {
        $metadataCommand.Parameters["@SourceModifiedDate"].Value =
            [DateTime]::Parse($modified)
    }
    else {
        $metadataCommand.Parameters["@SourceModifiedDate"].Value =
            [DBNull]::Value
    }

    $reader = $metadataCommand.ExecuteReader()

    if ($reader.Read()) {
        $existingSourceFileId = [long]$reader["SourceFileId"]
        $existingFileName = [string]$reader["FileName"]
        $existingDownloadedUtc = $reader["DownloadedUtc"]
        $existingFileSizeBytes = [long]$reader["FileSizeBytes"]
        $existingSha256 = [string]$reader["Sha256"]
        $existingIsProcessed = [bool]$reader["IsProcessed"]

        $reader.Close()

        $existingPath =
            Join-Path $OutputDirectory $existingFileName

        $localFileExists =
            Test-Path $existingPath

        Write-Host ""
        Write-Host "No new CMS distribution detected."
        Write-Host "Skipping download."
        Write-Host ""
        Write-Host "  SourceFileId:      $existingSourceFileId"
        Write-Host "  FileName:          $existingFileName"
        Write-Host "  Downloaded:        $existingDownloadedUtc"
        Write-Host "  Processed:         $existingIsProcessed"
        Write-Host "  Local file exists: $localFileExists"
        Write-Host "  SHA256:            $existingSha256"

        [PSCustomObject]@{
            IsNewFile        = $false
            DownloadSkipped  = $true
            SourceFileId     = $existingSourceFileId
            DatasetTitle     = $dataset.title
            Temporal         = $temporal
            Modified         = $modified
            DownloadUrl      = $downloadUrl
            FileName         = $existingFileName
            FilePath         = $existingPath
            LocalFileExists  = $localFileExists
            FileSizeBytes    = $existingFileSizeBytes
            Sha256           = $existingSha256
            IsProcessed      = $existingIsProcessed
        }

        return
    }

    $reader.Close()

    # --------------------------------------------------------
    # Metadata is new, so download CMS file
    # --------------------------------------------------------

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $outputFile = Join-Path `
        $OutputDirectory `
        "Medicare_Monthly_Enrollment_$timestamp.csv"

    Write-Host ""
    Write-Host "New CMS distribution detected."
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

    # --------------------------------------------------------
    # Final SHA256 duplicate protection
    #
    # Metadata could theoretically change while the actual file
    # remains identical, so hash remains the authoritative test.
    # --------------------------------------------------------

    $hashCommand = $connection.CreateCommand()

    $hashCommand.CommandText = @"
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

    $null = $hashCommand.Parameters.Add(
        "@DataSourceId",
        [System.Data.SqlDbType]::Int
    )
    $hashCommand.Parameters["@DataSourceId"].Value = $DataSourceId

    $null = $hashCommand.Parameters.Add(
        "@Sha256",
        [System.Data.SqlDbType]::Char,
        64
    )
    $hashCommand.Parameters["@Sha256"].Value = $sha256

    $reader = $hashCommand.ExecuteReader()

    if ($reader.Read()) {
        $existingSourceFileId = $reader["SourceFileId"]
        $existingFileName = $reader["FileName"]
        $existingDownloadedUtc = $reader["DownloadedUtc"]
        $existingIsProcessed = $reader["IsProcessed"]

        $reader.Close()

        Write-Host ""
        Write-Host "Downloaded file matches an existing SHA256."
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
            DownloadSkipped = $false
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

    # --------------------------------------------------------
    # Register genuinely new file
    # --------------------------------------------------------

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

    $sourceFileId =
        $insertCommand.ExecuteScalar()

    Write-Host ""
    Write-Host "New source file registered."
    Write-Host "  SourceFileId: $sourceFileId"

    [PSCustomObject]@{
        IsNewFile        = $true
        DownloadSkipped  = $false
        SourceFileId     = $sourceFileId
        DatasetTitle     = $dataset.title
        Temporal         = $temporal
        Modified         = $modified
        DownloadUrl      = $downloadUrl
        FileName         = $file.Name
        FilePath         = $file.FullName
        FileSizeBytes    = $file.Length
        Sha256           = $sha256
        IsProcessed      = $false
    }
}
finally {
    if ($connection.State -eq "Open") {
        $connection.Close()
    }

    $connection.Dispose()
}
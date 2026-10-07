[CmdletBinding()]
param (
    [string]$SqlServer = "localhost,57064",
    [string]$Database = "HealthcareHub"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

$downloadScript =
    Join-Path $PSScriptRoot "Download-MedicareMonthlyEnrollmentTracked.ps1"

$rawImportScript =
    Join-Path $PSScriptRoot "Import-MedicareMonthlyEnrollmentRaw.ps1"

$prepareSql =
    Join-Path $repoRoot "database\014_prepare_incremental_medicare_pipeline.sql"

$stageSql =
    Join-Path $repoRoot "database\015_load_medicare_monthly_enrollment_stage_incremental.sql"

$coreSql =
    Join-Path $repoRoot "database\016_load_core_medicare_enrollment_incremental.sql"

$completeSql =
    Join-Path $repoRoot "database\017_complete_medicare_pipeline_run.sql"

$connectionString =
    "Server=$SqlServer;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"

function Invoke-HealthcareHubSqlScript {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [long]$SourceFileId = 0,

        [long]$PipelineRunId = 0
    )

    if (-not (Test-Path $Path)) {
        throw "SQL script was not found: $Path"
    }

    $sql = Get-Content `
        -Path $Path `
        -Raw

    if ($SourceFileId -gt 0) {
        $sql = $sql -replace `
            'DECLARE\s+@SourceFileId\s+BIGINT\s*=\s*\d+\s*;', `
            "DECLARE @SourceFileId BIGINT = $SourceFileId;"
    }

    if ($PipelineRunId -gt 0) {
        $sql = $sql -replace `
            'DECLARE\s+@PipelineRunId\s+BIGINT\s*=\s*\d+\s*;', `
            "DECLARE @PipelineRunId BIGINT = $PipelineRunId;"
    }

    # SQL Server itself does not understand GO.
    # Split the file into executable batches.
    $batches =
        [regex]::Split(
            $sql,
            '(?im)^\s*GO\s*$'
        ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }

    $connection =
        New-Object System.Data.SqlClient.SqlConnection

    $connection.ConnectionString =
        $connectionString

    try {
        $connection.Open()

        foreach ($batch in $batches) {

            $command =
                $connection.CreateCommand()

            $command.CommandText = $batch
            $command.CommandTimeout = 300

            $null =
                $command.ExecuteNonQuery()
        }
    }
    finally {
        if ($connection.State -eq "Open") {
            $connection.Close()
        }

        $connection.Dispose()
    }
}

function Get-SourceFileState {
    param (
        [Parameter(Mandatory = $true)]
        [long]$SourceFileId
    )

    $connection =
        New-Object System.Data.SqlClient.SqlConnection

    $connection.ConnectionString =
        $connectionString

    try {
        $connection.Open()

        $command =
            $connection.CreateCommand()

        $command.CommandText = @"
SELECT
    sf.SourceFileId,
    sf.PipelineRunId,
    sf.IsProcessed,
    sf.FileName,
    sf.ReportingPeriodStart,
    sf.ReportingPeriodEnd,

    pr.Status AS PipelineStatus,

    (
        SELECT COUNT_BIG(*)
        FROM raw.MedicareMonthlyEnrollment r
        WHERE r.PipelineRunId = sf.PipelineRunId
    ) AS RawCount,

    (
        SELECT COUNT_BIG(*)
        FROM stage.MedicareMonthlyEnrollment s
        WHERE s.PipelineRunId = sf.PipelineRunId
    ) AS StageCount,

    (
        SELECT COUNT_BIG(*)
        FROM core.MedicareEnrollment c
        WHERE c.PipelineRunId = sf.PipelineRunId
    ) AS CoreCount

FROM ops.SourceFile sf

LEFT JOIN ops.PipelineRun pr
    ON pr.PipelineRunId = sf.PipelineRunId

WHERE sf.SourceFileId = @SourceFileId;
"@

        $null =
            $command.Parameters.Add(
                "@SourceFileId",
                [System.Data.SqlDbType]::BigInt
            )

        $command.Parameters["@SourceFileId"].Value =
            $SourceFileId

        $reader =
            $command.ExecuteReader()

        if (-not $reader.Read()) {
            $reader.Close()
            throw "SourceFileId $SourceFileId was not found."
        }

        $result =
            [PSCustomObject]@{
                SourceFileId =
                    [long]$reader["SourceFileId"]

                PipelineRunId =
                    if ($reader["PipelineRunId"] -eq [DBNull]::Value) {
                        $null
                    }
                    else {
                        [long]$reader["PipelineRunId"]
                    }

                IsProcessed =
                    [bool]$reader["IsProcessed"]

                FileName =
                    [string]$reader["FileName"]

                ReportingPeriodStart =
                    $reader["ReportingPeriodStart"]

                ReportingPeriodEnd =
                    $reader["ReportingPeriodEnd"]

                PipelineStatus =
                    if ($reader["PipelineStatus"] -eq [DBNull]::Value) {
                        $null
                    }
                    else {
                        [string]$reader["PipelineStatus"]
                    }

                RawCount =
                    [long]$reader["RawCount"]

                StageCount =
                    [long]$reader["StageCount"]

                CoreCount =
                    [long]$reader["CoreCount"]
            }

        $reader.Close()

        return $result
    }
    finally {
        if ($connection.State -eq "Open") {
            $connection.Close()
        }

        $connection.Dispose()
    }
}

function Set-PipelineFailed {
    param (
        [Parameter(Mandatory = $true)]
        [long]$PipelineRunId,

        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )

    $connection =
        New-Object System.Data.SqlClient.SqlConnection

    $connection.ConnectionString =
        $connectionString

    try {
        $connection.Open()

        $command =
            $connection.CreateCommand()

        $command.CommandText = @"
UPDATE ops.PipelineRun
SET
    Status = 'Failed',
    CompletedUtc = SYSUTCDATETIME(),
    ErrorMessage = LEFT(@ErrorMessage, 1000)
WHERE PipelineRunId = @PipelineRunId;
"@

        $null =
            $command.Parameters.Add(
                "@PipelineRunId",
                [System.Data.SqlDbType]::BigInt
            )

        $command.Parameters["@PipelineRunId"].Value =
            $PipelineRunId

        $null =
            $command.Parameters.Add(
                "@ErrorMessage",
                [System.Data.SqlDbType]::NVarChar,
                1000
            )

        $command.Parameters["@ErrorMessage"].Value =
            $ErrorMessage

        $null =
            $command.ExecuteNonQuery()
    }
    finally {
        if ($connection.State -eq "Open") {
            $connection.Close()
        }

        $connection.Dispose()
    }
}

Write-Host ""
Write-Host "============================================"
Write-Host " HealthcareHub Medicare Enrollment Pipeline"
Write-Host "============================================"
Write-Host ""

$pipelineRunId = $null

try {

    # --------------------------------------------------------
    # 1. Discover/download CMS source
    # --------------------------------------------------------

    Write-Host "STEP 1 - Checking CMS source..."
    Write-Host ""

    $source =
        & $downloadScript `
            -SqlServer $SqlServer `
            -Database $Database

    $sourceFileId =
        [long]$source.SourceFileId

    Write-Host ""
    Write-Host "SourceFileId: $sourceFileId"

    $state =
        Get-SourceFileState `
            -SourceFileId $sourceFileId

    # --------------------------------------------------------
    # Nothing to do
    # --------------------------------------------------------

    if ($state.IsProcessed) {

        Write-Host ""
        Write-Host "Source file has already been processed."
        Write-Host "No pipeline work is required."
        Write-Host ""
        Write-Host "HealthcareHub is current."

        return
    }

    # --------------------------------------------------------
    # 2. Prepare PipelineRun if necessary
    # --------------------------------------------------------

    if (-not $state.PipelineRunId) {

        Write-Host ""
        Write-Host "STEP 2 - Creating pipeline run..."

        Invoke-HealthcareHubSqlScript `
            -Path $prepareSql `
            -SourceFileId $sourceFileId

        $state =
            Get-SourceFileState `
                -SourceFileId $sourceFileId
    }
    else {
        Write-Host ""
        Write-Host "STEP 2 - Existing pipeline run found."
        Write-Host "Resuming PipelineRunId $($state.PipelineRunId)."
    }

    $pipelineRunId =
        [long]$state.PipelineRunId

    Write-Host "PipelineRunId: $pipelineRunId"

    # --------------------------------------------------------
    # 3. RAW
    # --------------------------------------------------------

    if ($state.RawCount -eq 0) {

        Write-Host ""
        Write-Host "STEP 3 - Loading RAW..."

        & $rawImportScript `
            -SourceFileId $sourceFileId `
            -SqlServer $SqlServer `
            -Database $Database |
            Out-Host
    }
    else {
        Write-Host ""
        Write-Host "STEP 3 - RAW already loaded."
        Write-Host "Rows: $($state.RawCount)"
    }

    $state =
        Get-SourceFileState `
            -SourceFileId $sourceFileId

    if ($state.RawCount -eq 0) {
        throw "RAW load contains zero rows."
    }

    # --------------------------------------------------------
    # 4. STAGE
    # --------------------------------------------------------

    if ($state.StageCount -eq 0) {

        Write-Host ""
        Write-Host "STEP 4 - Loading STAGE..."

        Invoke-HealthcareHubSqlScript `
            -Path $stageSql `
            -PipelineRunId $pipelineRunId
    }
    else {
        Write-Host ""
        Write-Host "STEP 4 - STAGE already loaded."
        Write-Host "Rows: $($state.StageCount)"
    }

    $state =
        Get-SourceFileState `
            -SourceFileId $sourceFileId

    if ($state.RawCount -ne $state.StageCount) {
        throw "RAW/STAGE validation failed. RAW=$($state.RawCount), STAGE=$($state.StageCount)"
    }

    # --------------------------------------------------------
    # 5. CORE
    # --------------------------------------------------------

    if ($state.CoreCount -eq 0) {

        Write-Host ""
        Write-Host "STEP 5 - Loading CORE..."

        Invoke-HealthcareHubSqlScript `
            -Path $coreSql `
            -PipelineRunId $pipelineRunId
    }
    else {
        Write-Host ""
        Write-Host "STEP 5 - CORE already loaded."
        Write-Host "Rows: $($state.CoreCount)"
    }

    $state =
        Get-SourceFileState `
            -SourceFileId $sourceFileId

    if ($state.StageCount -ne $state.CoreCount) {
        throw "STAGE/CORE validation failed. STAGE=$($state.StageCount), CORE=$($state.CoreCount)"
    }

    # --------------------------------------------------------
    # 6. Complete run
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "STEP 6 - Completing pipeline run..."

    Invoke-HealthcareHubSqlScript `
        -Path $completeSql `
        -SourceFileId $sourceFileId `
        -PipelineRunId $pipelineRunId

    $state =
        Get-SourceFileState `
            -SourceFileId $sourceFileId

    if (-not $state.IsProcessed) {
        throw "Source file was not marked processed."
    }

    if ($state.PipelineStatus -ne "Success") {
        throw "Pipeline run did not finish with Success status."
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host " Pipeline completed successfully"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "SourceFileId:  $sourceFileId"
    Write-Host "PipelineRunId: $pipelineRunId"
    Write-Host "RAW rows:      $($state.RawCount)"
    Write-Host "STAGE rows:    $($state.StageCount)"
    Write-Host "CORE rows:     $($state.CoreCount)"
    Write-Host "Status:        $($state.PipelineStatus)"
}
catch {

    $message =
        $_.Exception.Message

    Write-Host ""
    Write-Host "PIPELINE FAILED"
    Write-Host $message

    if ($pipelineRunId) {

        try {
            Set-PipelineFailed `
                -PipelineRunId $pipelineRunId `
                -ErrorMessage $message
        }
        catch {
            Write-Warning `
                "Pipeline failed and the failure status could not be written to SQL."
        }
    }

    throw
}
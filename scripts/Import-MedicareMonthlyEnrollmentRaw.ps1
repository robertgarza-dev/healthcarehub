[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [long]$SourceFileId,

    [string]$SqlServer = "localhost,57064",

    [string]$Database = "HealthcareHub"
)

$ErrorActionPreference = "Stop"

$connectionString =
    "Server=$SqlServer;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"

$connection =
    New-Object System.Data.SqlClient.SqlConnection

$connection.ConnectionString = $connectionString

try {
    $connection.Open()

    # --------------------------------------------------------
    # 1. Get tracked source-file information
    # --------------------------------------------------------

    $command = $connection.CreateCommand()

    $command.CommandText = @"
SELECT
    SourceFileId,
    PipelineRunId,
    FileName,
    ReportingPeriodStart,
    ReportingPeriodEnd,
    IsProcessed
FROM ops.SourceFile
WHERE SourceFileId = @SourceFileId;
"@

    $null = $command.Parameters.Add(
        "@SourceFileId",
        [System.Data.SqlDbType]::BigInt
    )

    $command.Parameters["@SourceFileId"].Value =
        $SourceFileId

    $reader = $command.ExecuteReader()

    if (-not $reader.Read()) {
        $reader.Close()
        throw "SourceFileId $SourceFileId was not found."
    }

    $pipelineRunId =
        if ($reader["PipelineRunId"] -eq [DBNull]::Value) {
            $null
        }
        else {
            [long]$reader["PipelineRunId"]
        }

    $fileName = [string]$reader["FileName"]

    $reportingPeriodStart =
        if ($reader["ReportingPeriodStart"] -eq [DBNull]::Value) {
            $null
        }
        else {
            [DateTime]$reader["ReportingPeriodStart"]
        }

    $reportingPeriodEnd =
        if ($reader["ReportingPeriodEnd"] -eq [DBNull]::Value) {
            $null
        }
        else {
            [DateTime]$reader["ReportingPeriodEnd"]
        }

    $isProcessed = [bool]$reader["IsProcessed"]

    $reader.Close()

    if (-not $pipelineRunId) {
        throw "SourceFileId $SourceFileId is not associated with a PipelineRun."
    }

    if (-not $reportingPeriodStart -or -not $reportingPeriodEnd) {
        throw "SourceFileId $SourceFileId does not have a complete reporting period."
    }

    if ($isProcessed) {
        throw "SourceFileId $SourceFileId is already marked as processed."
    }

    # --------------------------------------------------------
    # 2. Locate source file
    # --------------------------------------------------------

    $filePath = Join-Path `
        ".\data\source\medicare-monthly-enrollment" `
        $fileName

    if (-not (Test-Path $filePath)) {
        throw "Source file was not found: $filePath"
    }

    $targetYear =
        $reportingPeriodStart.Year.ToString()

    $targetMonth =
        $reportingPeriodStart.ToString(
            "MMMM",
            [System.Globalization.CultureInfo]::InvariantCulture
        )

    Write-Host "HealthcareHub - Medicare RAW incremental load"
    Write-Host ""
    Write-Host "SourceFileId:   $SourceFileId"
    Write-Host "PipelineRunId:  $pipelineRunId"
    Write-Host "File:           $fileName"
    Write-Host "Target period:  $targetMonth $targetYear"
    Write-Host ""

    # --------------------------------------------------------
    # 3. Make sure this run has not already loaded RAW rows
    # --------------------------------------------------------

    $checkCommand = $connection.CreateCommand()

    $checkCommand.CommandText = @"
SELECT COUNT_BIG(*)
FROM raw.MedicareMonthlyEnrollment
WHERE PipelineRunId = @PipelineRunId;
"@

    $null = $checkCommand.Parameters.Add(
        "@PipelineRunId",
        [System.Data.SqlDbType]::BigInt
    )

    $checkCommand.Parameters["@PipelineRunId"].Value =
        $pipelineRunId

    $existingRawCount =
        [long]$checkCommand.ExecuteScalar()

    if ($existingRawCount -gt 0) {
        throw "PipelineRunId $pipelineRunId already has $existingRawCount RAW rows. Load aborted."
    }

    # --------------------------------------------------------
    # 4. Define source CSV columns
    # --------------------------------------------------------

    $sourceColumns = @(
        "YEAR",
        "MONTH",
        "BENE_GEO_LVL",
        "BENE_STATE_ABRVTN",
        "BENE_STATE_DESC",
        "BENE_COUNTY_DESC",
        "BENE_FIPS_CD",
        "TOT_BENES",
        "ORGNL_MDCR_BENES",
        "MA_AND_OTH_BENES",
        "AGED_TOT_BENES",
        "AGED_ESRD_BENES",
        "AGED_NO_ESRD_BENES",
        "DSBLD_TOT_BENES",
        "DSBLD_ESRD_AND_ESRD_ONLY_BENES",
        "DSBLD_NO_ESRD_BENES",
        "MALE_TOT_BENES",
        "FEMALE_TOT_BENES",
        "WHITE_TOT_BENES",
        "BLACK_TOT_BENES",
        "API_TOT_BENES",
        "HSPNC_TOT_BENES",
        "NATIND_TOT_BENES",
        "OTHR_TOT_BENES",
        "AGE_LT_25_BENES",
        "AGE_25_TO_44_BENES",
        "AGE_45_TO_64_BENES",
        "AGE_65_TO_69_BENES",
        "AGE_70_TO_74_BENES",
        "AGE_75_TO_79_BENES",
        "AGE_80_TO_84_BENES",
        "AGE_85_TO_89_BENES",
        "AGE_90_TO_94_BENES",
        "AGE_GT_94_BENES",
        "DUAL_TOT_BENES",
        "FULL_DUAL_TOT_BENES",
        "PART_DUAL_TOT_BENES",
        "NODUAL_TOT_BENES",
        "QMB_ONLY_BENES",
        "QMB_PLUS_BENES",
        "SLMB_ONLY_BENES",
        "SLMB_PLUS_BENES",
        "QDWI_QI_BENES",
        "OTHR_FULL_DUAL_MDCD_BENES",
        "A_B_TOT_BENES",
        "A_B_ORGNL_MDCR_BENES",
        "A_B_MA_AND_OTH_BENES",
        "A_TOT_BENES",
        "A_ORGNL_MDCR_BENES",
        "A_MA_AND_OTH_BENES",
        "B_TOT_BENES",
        "B_ORGNL_MDCR_BENES",
        "B_MA_AND_OTH_BENES",
        "PRSCRPTN_DRUG_TOT_BENES",
        "PRSCRPTN_DRUG_PDP_BENES",
        "PRSCRPTN_DRUG_MAPD_BENES",
        "PRSCRPTN_DRUG_DEEMED_ELIGIBLE_FULL_LIS_BENES",
        "PRSCRPTN_DRUG_FULL_LIS_BENES",
        "PRSCRPTN_DRUG_PARTIAL_LIS_BENES",
        "PRSCRPTN_DRUG_NO_LIS_BENES"
    )

    # --------------------------------------------------------
    # 5. Build an in-memory table containing ONLY the
    #    incremental reporting month
    # --------------------------------------------------------

    $table = New-Object System.Data.DataTable

    $null =
        $table.Columns.Add(
            "PipelineRunId",
            [long]
        )

    $null =
        $table.Columns.Add(
            "YEAR",
            [Int16]
        )

    foreach ($column in $sourceColumns | Select-Object -Skip 1) {
        $null =
            $table.Columns.Add(
                $column,
                [string]
            )
    }

    $null =
        $table.Columns.Add(
            "SourceFileName",
            [string]
        )

    Write-Host "Reading CMS CSV and selecting $targetMonth $targetYear..."

    $matchedRows = 0

    Import-Csv $filePath |
        Where-Object {
            $_.YEAR -eq $targetYear -and
            $_.MONTH -eq $targetMonth
        } |
        ForEach-Object {

            $row = $table.NewRow()

            $row["PipelineRunId"] =
                $pipelineRunId

            $row["YEAR"] =
                [Int16]$_.YEAR

            foreach ($column in $sourceColumns | Select-Object -Skip 1) {

                $value = $_.$column

                if ($null -eq $value) {
                    $row[$column] = [DBNull]::Value
                }
                else {
                    $row[$column] = [string]$value
                }
            }

            $row["SourceFileName"] =
                $fileName

            $table.Rows.Add($row)

            $matchedRows++
        }

    Write-Host "Rows selected: $matchedRows"

    if ($matchedRows -eq 0) {
        throw "No rows were found for $targetMonth $targetYear."
    }

    # --------------------------------------------------------
    # 6. Bulk load RAW
    # --------------------------------------------------------

    Write-Host "Loading RAW..."

    $bulkCopy =
        New-Object System.Data.SqlClient.SqlBulkCopy($connection)

    try {
        $bulkCopy.DestinationTableName =
            "raw.MedicareMonthlyEnrollment"

        $bulkCopy.BatchSize = 1000
        $bulkCopy.BulkCopyTimeout = 300

        $null =
            $bulkCopy.ColumnMappings.Add(
                "PipelineRunId",
                "PipelineRunId"
            )

        foreach ($column in $sourceColumns) {
            $null =
                $bulkCopy.ColumnMappings.Add(
                    $column,
                    $column
                )
        }

        $null =
            $bulkCopy.ColumnMappings.Add(
                "SourceFileName",
                "SourceFileName"
            )

        $bulkCopy.WriteToServer($table)
    }
    finally {
        $bulkCopy.Close()
        $bulkCopy.Dispose()
    }

    # --------------------------------------------------------
    # 7. Verify RAW count
    # --------------------------------------------------------

    $verifyCommand = $connection.CreateCommand()

    $verifyCommand.CommandText = @"
SELECT COUNT_BIG(*)
FROM raw.MedicareMonthlyEnrollment
WHERE PipelineRunId = @PipelineRunId;
"@

    $null = $verifyCommand.Parameters.Add(
        "@PipelineRunId",
        [System.Data.SqlDbType]::BigInt
    )

    $verifyCommand.Parameters["@PipelineRunId"].Value =
        $pipelineRunId

    $rawCount =
        [long]$verifyCommand.ExecuteScalar()

    Write-Host ""
    Write-Host "RAW load complete."
    Write-Host "  PipelineRunId: $pipelineRunId"
    Write-Host "  Rows selected: $matchedRows"
    Write-Host "  RAW rows:      $rawCount"

    if ($rawCount -ne $matchedRows) {
        throw "RAW validation failed. Selected $matchedRows rows but RAW contains $rawCount."
    }

    [PSCustomObject]@{
        SourceFileId    = $SourceFileId
        PipelineRunId   = $pipelineRunId
        ReportingPeriod = "$targetMonth $targetYear"
        RowsSelected    = $matchedRows
        RawRowsLoaded   = $rawCount
        FileName        = $fileName
    }
}
catch {
    Write-Error $_
    throw
}
finally {
    if ($connection.State -eq "Open") {
        $connection.Close()
    }

    $connection.Dispose()
}
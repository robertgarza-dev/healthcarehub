[CmdletBinding()]
param (
    [string]$SourceServer = "localhost,57064",
    [string]$SourceDatabase = "HealthcareHub",

    [string]$TargetServer =
        "sql-healthcarehub-robert-dev.database.windows.net",

    [string]$TargetDatabase =
        "sqldb-healthcarehub-dev",

    [string]$TargetUser =
        "healthcarehubadmin",

    [int]$BatchSize = 1000
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "HealthcareHub - Local to Azure SQL migration"
Write-Host ""

# ------------------------------------------------------------
# Azure SQL password
# ------------------------------------------------------------

$securePassword =
    Read-Host "Enter Azure SQL password" -AsSecureString

$ptr =
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $securePassword
    )

try {
    $targetPassword =
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $ptr
        )
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
        $ptr
    )
}

# ------------------------------------------------------------
# Connection strings
# ------------------------------------------------------------

$sourceConnectionString =
    "Server=$SourceServer;" +
    "Database=$SourceDatabase;" +
    "Integrated Security=True;" +
    "TrustServerCertificate=True;"

$targetConnectionString =
    "Server=tcp:$TargetServer,1433;" +
    "Initial Catalog=$TargetDatabase;" +
    "User ID=$TargetUser;" +
    "Password=$targetPassword;" +
    "Encrypt=True;" +
    "TrustServerCertificate=False;" +
    "Connection Timeout=60;"

# Foreign-key-safe copy order.
$tables = @(
    "ops.DataSource",
    "ops.PipelineRun",
    "raw.MedicareMonthlyEnrollment",
    "stage.MedicareMonthlyEnrollment",
    "core.Geography",
    "core.ReportingPeriod",
    "core.MedicareEnrollment",
    "ops.SourceFile"
)

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

function New-SqlConnection {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConnectionString,

        [int]$MaxAttempts = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {

        $connection =
            New-Object System.Data.SqlClient.SqlConnection(
                $ConnectionString
            )

        try {
            $connection.Open()
            return $connection
        }
        catch {
            $connection.Dispose()

            if ($attempt -ge $MaxAttempts) {
                throw
            }

            $delaySeconds = $attempt * 5

            Write-Warning `
                "SQL connection failed. Retrying in $delaySeconds seconds (attempt $attempt of $MaxAttempts)..."

            Start-Sleep -Seconds $delaySeconds
        }
    }
}

function Get-ScalarCount {
    param (
        [string]$ConnectionString,
        [string]$TableName
    )

    $connection =
        New-SqlConnection `
            -ConnectionString $ConnectionString

    try {
        $command =
            $connection.CreateCommand()

        $command.CommandText =
            "SELECT COUNT_BIG(*) FROM $TableName;"

        return [long]$command.ExecuteScalar()
    }
    finally {
        $connection.Close()
        $connection.Dispose()
    }
}

function Get-CopyableColumns {
    param (
        [string]$ConnectionString,
        [string]$SchemaName,
        [string]$TableName
    )

    $connection =
        New-SqlConnection `
            -ConnectionString $ConnectionString

    try {
        $command =
            $connection.CreateCommand()

        $command.CommandText = @"
SELECT
    c.name
FROM sys.columns c
JOIN sys.tables t
    ON t.object_id = c.object_id
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
WHERE s.name = @SchemaName
  AND t.name = @TableName
  AND c.is_computed = 0
ORDER BY c.column_id;
"@

        $null =
            $command.Parameters.Add(
                "@SchemaName",
                [System.Data.SqlDbType]::NVarChar,
                128
            )

        $command.Parameters["@SchemaName"].Value =
            $SchemaName

        $null =
            $command.Parameters.Add(
                "@TableName",
                [System.Data.SqlDbType]::NVarChar,
                128
            )

        $command.Parameters["@TableName"].Value =
            $TableName

        $reader =
            $command.ExecuteReader()

        $columns =
            New-Object System.Collections.Generic.List[string]

        while ($reader.Read()) {
            $columns.Add(
                [string]$reader["name"]
            )
        }

        $reader.Close()

        return $columns
    }
    finally {
        $connection.Close()
        $connection.Dispose()
    }
}

function Get-IdentityColumn {
    param (
        [string]$ConnectionString,
        [string]$SchemaName,
        [string]$TableName
    )

    $connection =
        New-SqlConnection `
            -ConnectionString $ConnectionString

    try {
        $command =
            $connection.CreateCommand()

        $command.CommandText = @"
SELECT TOP (1)
    c.name
FROM sys.columns c
JOIN sys.tables t
    ON t.object_id = c.object_id
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
WHERE s.name = @SchemaName
  AND t.name = @TableName
  AND c.is_identity = 1
ORDER BY c.column_id;
"@

        $null =
            $command.Parameters.Add(
                "@SchemaName",
                [System.Data.SqlDbType]::NVarChar,
                128
            )

        $command.Parameters["@SchemaName"].Value =
            $SchemaName

        $null =
            $command.Parameters.Add(
                "@TableName",
                [System.Data.SqlDbType]::NVarChar,
                128
            )

        $command.Parameters["@TableName"].Value =
            $TableName

        $result =
            $command.ExecuteScalar()

        if ($null -eq $result -or
            $result -eq [DBNull]::Value) {
            return $null
        }

        return [string]$result
    }
    finally {
        $connection.Close()
        $connection.Dispose()
    }
}

function Get-MaxIdentityValue {
    param (
        [string]$ConnectionString,
        [string]$TableName,
        [string]$IdentityColumn
    )

    $connection =
        New-SqlConnection `
            -ConnectionString $ConnectionString

    try {
        $command =
            $connection.CreateCommand()

        $command.CommandText =
            "SELECT ISNULL(MAX([$IdentityColumn]), 0) FROM $TableName;"

        return [long]$command.ExecuteScalar()
    }
    finally {
        $connection.Close()
        $connection.Dispose()
    }
}

# ------------------------------------------------------------
# Migration
# ------------------------------------------------------------

try {

    foreach ($fullTableName in $tables) {

        $parts =
            $fullTableName.Split(".")

        $schemaName =
            $parts[0]

        $tableName =
            $parts[1]

        Write-Host ""
        Write-Host "--------------------------------------------"
        Write-Host "Processing $fullTableName"

        $sourceCount =
            Get-ScalarCount `
                -ConnectionString $sourceConnectionString `
                -TableName $fullTableName

        $targetCount =
            Get-ScalarCount `
                -ConnectionString $targetConnectionString `
                -TableName $fullTableName

        Write-Host "Local rows: $sourceCount"
        Write-Host "Azure rows: $targetCount"

        # Already migrated.
        if ($sourceCount -eq $targetCount) {
            Write-Host "Already complete. Skipping."
            continue
        }

        if ($targetCount -gt $sourceCount) {
            throw "$fullTableName contains more rows in Azure than locally. Migration stopped."
        }

        $columns =
            Get-CopyableColumns `
                -ConnectionString $sourceConnectionString `
                -SchemaName $schemaName `
                -TableName $tableName

        if ($columns.Count -eq 0) {
            throw "No copyable columns found for $fullTableName."
        }

        $identityColumn =
            Get-IdentityColumn `
                -ConnectionString $sourceConnectionString `
                -SchemaName $schemaName `
                -TableName $tableName

        if (-not $identityColumn) {
            throw "No identity column found for $fullTableName."
        }

        $columnList =
            ($columns |
                ForEach-Object {
                    "[$_]"
                }) -join ", "

        # Resume after the highest identity already present in Azure.
        $lastIdentityValue =
            Get-MaxIdentityValue `
                -ConnectionString $targetConnectionString `
                -TableName $fullTableName `
                -IdentityColumn $identityColumn

        $totalCopied =
            $targetCount

        if ($targetCount -gt 0) {
            Write-Host `
                "Resuming after $identityColumn = $lastIdentityValue"
        }

        while ($true) {

            # ------------------------------------------------
            # Read next local batch
            # ------------------------------------------------

            $sourceConnection =
                New-SqlConnection `
                    -ConnectionString $sourceConnectionString

            try {
                $sourceCommand =
                    $sourceConnection.CreateCommand()

                $sourceCommand.CommandTimeout = 0

                $sourceCommand.CommandText = @"
SELECT TOP ($BatchSize)
    $columnList
FROM $fullTableName
WHERE [$identityColumn] > @LastIdentityValue
ORDER BY [$identityColumn];
"@

                $null =
                    $sourceCommand.Parameters.Add(
                        "@LastIdentityValue",
                        [System.Data.SqlDbType]::BigInt
                    )

                $sourceCommand.Parameters[
                    "@LastIdentityValue"
                ].Value = $lastIdentityValue

                $adapter =
                    New-Object System.Data.SqlClient.SqlDataAdapter(
                        $sourceCommand
                    )

                $batch =
                    New-Object System.Data.DataTable

                $null =
                    $adapter.Fill($batch)

                $adapter.Dispose()
            }
            finally {
                $sourceConnection.Close()
                $sourceConnection.Dispose()
            }

            if ($batch.Rows.Count -eq 0) {
                break
            }

            # ------------------------------------------------
            # Write Azure batch with retry
            # ------------------------------------------------

            $maxAttempts =
                5

            $batchCopied =
                $false

            for (
                $attempt = 1;
                $attempt -le $maxAttempts;
                $attempt++
            ) {

                $targetConnection =
                    $null

                $bulkCopy =
                    $null

                try {

                    $targetConnection =
                        New-SqlConnection `
                            -ConnectionString $targetConnectionString

                    $bulkOptions =
                        [System.Data.SqlClient.SqlBulkCopyOptions]::KeepIdentity `
                        -bor `
                        [System.Data.SqlClient.SqlBulkCopyOptions]::CheckConstraints `
                        -bor `
                        [System.Data.SqlClient.SqlBulkCopyOptions]::UseInternalTransaction

                    $bulkCopy =
                        New-Object System.Data.SqlClient.SqlBulkCopy(
                            $targetConnection,
                            $bulkOptions,
                            $null
                        )

                    $bulkCopy.DestinationTableName =
                        $fullTableName

                    $bulkCopy.BatchSize =
                        $BatchSize

                    $bulkCopy.BulkCopyTimeout =
                        300

                    foreach ($column in $columns) {
                        $null =
                            $bulkCopy.ColumnMappings.Add(
                                $column,
                                $column
                            )
                    }

                    $bulkCopy.WriteToServer(
                        $batch
                    )

                    $batchCopied =
                        $true

                    break
                }
                catch {

                    if ($attempt -ge $maxAttempts) {
                        throw
                    }

                    $delaySeconds =
                        $attempt * 5

                    Write-Warning `
                        "Azure SQL batch failed. Retrying in $delaySeconds seconds (attempt $attempt of $maxAttempts)..."

                    Start-Sleep `
                        -Seconds $delaySeconds
                }
                finally {

                    if ($null -ne $bulkCopy) {
                        $bulkCopy.Close()
                        $bulkCopy.Dispose()
                    }

                    if ($null -ne $targetConnection) {
                        if (
                            $targetConnection.State -eq
                            [System.Data.ConnectionState]::Open
                        ) {
                            $targetConnection.Close()
                        }

                        $targetConnection.Dispose()
                    }
                }
            }

            if (-not $batchCopied) {
                throw "Batch copy failed for $fullTableName."
            }

            # Only advance our checkpoint AFTER the batch
            # successfully commits.
            $lastRow =
                $batch.Rows[
                    $batch.Rows.Count - 1
                ]

            $lastIdentityValue =
                [long]$lastRow[
                    $identityColumn
                ]

            $totalCopied +=
                $batch.Rows.Count

            Write-Host `
                "Copied $totalCopied / $sourceCount rows..."
        }

        # ----------------------------------------------------
        # Final validation
        # ----------------------------------------------------

        $targetCount =
            Get-ScalarCount `
                -ConnectionString $targetConnectionString `
                -TableName $fullTableName

        Write-Host "Final Azure rows: $targetCount"

        if ($sourceCount -ne $targetCount) {
            throw `
                "Row-count mismatch for $fullTableName. Local=$sourceCount Azure=$targetCount"
        }

        Write-Host "Validated."
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host " HealthcareHub Azure migration succeeded"
    Write-Host "============================================"
}
finally {
    $targetPassword = $null
}
param(
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

$catalogUrl = "https://data.cms.gov/data.json"

Write-Verbose "Reading CMS catalog..."

$catalog = Invoke-RestMethod `
    -Uri $catalogUrl `
    -Method Get

$dataset = $catalog.dataset |
    Where-Object {
        $_.title -like "*Medicare Monthly Enrollment*"
    } |
    Select-Object -First 1

if ($null -eq $dataset) {
    throw "Medicare Monthly Enrollment dataset was not found in the CMS catalog."
}

$distribution = @($dataset.distribution) |
    Where-Object {
        $_.downloadURL -and
        (
            $_.mediaType -eq "text/csv" -or
            $_.format -match "CSV"
        )
    } |
    Select-Object -First 1

if ($null -eq $distribution) {
    throw "CSV distribution was not found for Medicare Monthly Enrollment."
}

$temporal = $dataset.temporal

$reportingPeriodStart = $null
$reportingPeriodEnd = $null

if ($temporal -is [string]) {

    if ($temporal -match '^(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})$') {
        $reportingPeriodStart = $Matches[1]
        $reportingPeriodEnd = $Matches[2]
    }
}
elseif ($null -ne $temporal) {

    $temporalItem = @($temporal)[0]

    if ($temporalItem.PSObject.Properties.Name -contains "startDate") {
        $reportingPeriodStart = [string]$temporalItem.startDate
    }

    if ($temporalItem.PSObject.Properties.Name -contains "endDate") {
        $reportingPeriodEnd = [string]$temporalItem.endDate
    }
}

$modified = $null

if ($dataset.modified) {
    $modified = ([datetime]$dataset.modified).ToString("yyyy-MM-dd")
}

$result = [pscustomobject]@{
    DatasetTitle         = $dataset.title
    ReportingPeriodStart = $reportingPeriodStart
    ReportingPeriodEnd   = $reportingPeriodEnd
    SourceModifiedDate   = $modified
    DownloadUrl          = $distribution.downloadURL
}

if ($AsJson) {
    $result | ConvertTo-Json -Compress
}
else {
    Write-Host ""
    Write-Host "Latest CMS Medicare Monthly Enrollment release"
    Write-Host "------------------------------------------------"
    Write-Host "Dataset:  $($result.DatasetTitle)"
    Write-Host "Period:   $($result.ReportingPeriodStart) - $($result.ReportingPeriodEnd)"
    Write-Host "Modified: $($result.SourceModifiedDate)"
    Write-Host "URL:      $($result.DownloadUrl)"
    Write-Host ""

    $result
}
# HealthcareHub

HealthcareHub is a public Medicare and Medicaid data intelligence platform focused on **regularly refreshed government datasets and automated data operations**.

The goal is to build a real, continuously maintained data product: HealthcareHub checks authoritative public sources for new releases and revisions, ingests and validates them, transforms them into an analytical model, and publishes updated trends through a public web application.

## V1 Goals

HealthcareHub V1 will provide:

- Monthly Medicare enrollment trends
- Monthly Medicaid / CHIP enrollment trends
- Quarterly Medicare Part B prescription-drug spending trends
- Quarterly Medicare Part D prescription-drug spending trends
- Historical analysis back to 2020 where supported by the source
- National, state, and county geography where the selected source supports it
- Source freshness, reporting period, publication date, and load metadata
- Automatic detection of new source releases and revisions
- Data lineage and downloadable supporting detail where practical
- Pipeline health, row counts, errors, and refresh history

Annual datasets may be added as historical/geographic enrichment, but V1 prioritizes sources that normally refresh **at least quarterly**.

## Planned Core Data Sources

| Source | Program | Cadence | V1 Use |
| --- | --- | --- | --- |
| Medicare Monthly Enrollment | Medicare | Monthly | Enrollment and coverage trends; national/state/county geography |
| Medicare Quarterly Part B Spending by Drug | Medicare | Quarterly | Part B RX spending and utilization trends |
| Medicare Quarterly Part D Spending by Drug | Medicare | Quarterly | Part D RX spending and utilization trends |
| Medicaid & CHIP Eligibility Operations and Enrollment Snapshot | Medicaid / CHIP | Monthly | Enrollment and eligibility trends; national/state analysis |
| Medicaid Medical expenditure source | Medicaid | Pending | Included only if a whole-program source meeting the quarterly-or-better rule is validated |

## Supplemental Data

Potential supplemental sources include annual Medicare Geographic Variation data for historical state/county medical-spending analysis, annual Medicaid drug-spending data, and provider/service detail datasets. These sources will not be presented as more current than their actual reporting cadence.

## Architecture

```text
Government Data Source
        |
        v
Automated Source Check
        |
        v
New / Revised Version?
        |
        v
RAW -> STAGE -> CORE -> ANALYTICS
        |
        v
ASP.NET Core API
        |
        v
React / TypeScript Web App

Operational metadata and pipeline history are recorded throughout the process.
```

## Technology

- C# / .NET 10
- ASP.NET Core Web API
- React / TypeScript / Vite
- SQL Server / Azure SQL
- Azure Functions or .NET worker services
- PowerShell
- Git / GitHub
- GitHub Actions
- Azure Application Insights

## Repository Structure

```text
healthcarehub/
├── HealthcareHub.Api/
├── database/
├── docs/
├── scripts/
├── tests/
├── HealthcareHub.sln
└── README.md
```

## Current Status

Early development.

Completed foundation:

- Azure development subscription and resource group established
- Public GitHub repository initialized
- .NET 10 ASP.NET Core API initialized
- Health endpoint available at `/api/health`
- Local SQL Server `HealthcareHub` database created
- `raw`, `stage`, `core`, `analytics`, `etl`, and `ops` schemas created
- `ops.DataSource` and `ops.PipelineRun` foundation tables created

Current milestone:

**Finalize the cadence-first source matrix and build the first automated ingestion pipeline.**

## Data Principles

HealthcareHub will not manufacture precision that the underlying data does not provide.

- No invented monthly values from quarterly or annual data
- No invented county totals from state- or provider-level data
- Reporting period is kept separate from publication and load dates
- Preliminary, final, and revised data are identified when supported
- Combined metrics are calculated only when source periods and definitions are compatible
- Every displayed metric should be traceable to an authoritative government source

## Project Purpose

HealthcareHub is both a public data application and a portfolio project demonstrating data engineering, SQL, API development, cloud deployment, automation, monitoring, version control, and front-end analytics using real government data.

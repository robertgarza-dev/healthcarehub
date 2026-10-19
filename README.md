# HealthcareHub

HealthcareHub is a cloud-hosted healthcare data platform that ingests, transforms, and publishes public CMS data through a layered analytics pipeline.

The current implementation focuses on **Medicare Monthly Enrollment** data and demonstrates an end-to-end data engineering workflow:

- source discovery and release tracking
- ingestion and validation
- RAW → STAGE → CORE → ANALYTICS SQL modeling
- pipeline auditing and lineage
- ASP.NET Core API development
- React / TypeScript analytics
- Azure SQL, App Service, and Static Web Apps deployment

## Live Demo

**HealthcareHub Medicare Enrollment Dashboard**

https://mango-desert-05d3cdf1e.3.azurestaticapps.net

The public dashboard currently provides:

- monthly Medicare enrollment trends since January 2020
- national and state trend analysis
- latest county-level enrollment for selected states
- Original Medicare and Medicare Advantage enrollment
- Medicare Advantage share
- CMS data-source attribution
- latest reporting-period visibility
- pipeline-run and data-freshness information

## Current Data

### Medicare Monthly Enrollment

HealthcareHub currently uses the CMS Medicare Monthly Enrollment dataset.

The platform maintains data from 2020 forward and currently includes:

- National geography
- State and territory geography
- County geography
- Monthly reporting periods
- Annual summary observations retained separately from monthly analytics
- Enrollment and coverage measures
- CMS suppression handling
- Source and pipeline lineage

The currently published dashboard contains data through **June 2026**.

## Architecture

```text
CMS Public Data
       |
       v
Source Discovery / Release Detection
       |
       v
Source File Tracking
       |
       v
RAW
       |
       v
STAGE
       |
       v
CORE
       |
       v
ANALYTICS
       |
       v
Azure SQL Database
       |
       v
ASP.NET Core API
       |
       v
Azure App Service
       |
       v
React / TypeScript Dashboard
       |
       v
Azure Static Web Apps
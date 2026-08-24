CREATE DATABASE HealthcareHub;
GO

USE HealthcareHub;
GO

CREATE SCHEMA raw;
GO

CREATE SCHEMA stage;
GO

CREATE SCHEMA core;
GO

CREATE SCHEMA analytics;
GO

CREATE SCHEMA etl;
GO

CREATE SCHEMA ops;
GO

CREATE TABLE ops.DataSource
(
    DataSourceId        INT IDENTITY(1,1) PRIMARY KEY,
    SourceName          NVARCHAR(200) NOT NULL,
    SourceAgency        NVARCHAR(200) NOT NULL,
    SourceUrl           NVARCHAR(1000) NOT NULL,
    Program             NVARCHAR(50) NULL,
    SpendCategory       NVARCHAR(50) NULL,
    GeographicGrain     NVARCHAR(50) NULL,
    ReportingCadence    NVARCHAR(50) NULL,
    IsActive            BIT NOT NULL CONSTRAINT DF_DataSource_IsActive DEFAULT (1),
    CreatedUtc          DATETIME2(0) NOT NULL CONSTRAINT DF_DataSource_CreatedUtc DEFAULT (SYSUTCDATETIME())
);
GO

CREATE TABLE ops.PipelineRun
(
    PipelineRunId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    DataSourceId        INT NOT NULL,
    ReportingPeriod     NVARCHAR(50) NULL,
    StartedUtc          DATETIME2(0) NOT NULL CONSTRAINT DF_PipelineRun_StartedUtc DEFAULT (SYSUTCDATETIME()),
    CompletedUtc        DATETIME2(0) NULL,
    Status              NVARCHAR(30) NOT NULL,
    RowsRead            BIGINT NULL,
    RowsInserted        BIGINT NULL,
    RowsUpdated         BIGINT NULL,
    RowsRejected        BIGINT NULL,
    ErrorMessage        NVARCHAR(MAX) NULL,
    CONSTRAINT FK_PipelineRun_DataSource
        FOREIGN KEY (DataSourceId)
        REFERENCES ops.DataSource(DataSourceId)
);
GO
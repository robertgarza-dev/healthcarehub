USE HealthcareHub;
GO

CREATE TABLE ops.SourceFile
(
    SourceFileId BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_SourceFile PRIMARY KEY,

    DataSourceId INT NOT NULL,
    PipelineRunId BIGINT NULL,

    FileName NVARCHAR(260) NOT NULL,
    DownloadUrl NVARCHAR(1000) NOT NULL,

    ReportingPeriodStart DATE NULL,
    ReportingPeriodEnd DATE NULL,
    SourceModifiedDate DATE NULL,

    DownloadedUtc DATETIME2(0) NOT NULL
        CONSTRAINT DF_SourceFile_DownloadedUtc
        DEFAULT SYSUTCDATETIME(),

    FileSizeBytes BIGINT NOT NULL,
    Sha256 CHAR(64) NOT NULL,

    IsProcessed BIT NOT NULL
        CONSTRAINT DF_SourceFile_IsProcessed
        DEFAULT (0),

    ProcessedUtc DATETIME2(0) NULL,

    CreatedUtc DATETIME2(0) NOT NULL
        CONSTRAINT DF_SourceFile_CreatedUtc
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_SourceFile_DataSource
        FOREIGN KEY (DataSourceId)
        REFERENCES ops.DataSource(DataSourceId),

    CONSTRAINT FK_SourceFile_PipelineRun
        FOREIGN KEY (PipelineRunId)
        REFERENCES ops.PipelineRun(PipelineRunId)
);
GO

CREATE UNIQUE INDEX UX_SourceFile_DataSource_Sha256
    ON ops.SourceFile(DataSourceId, Sha256);
GO

CREATE INDEX IX_SourceFile_DataSource_ReportingPeriod
    ON ops.SourceFile
    (
        DataSourceId,
        ReportingPeriodStart,
        ReportingPeriodEnd
    );
GO
USE HealthcareHub;
GO

CREATE TABLE core.ReportingPeriod
(
    ReportingPeriodId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Core_ReportingPeriod PRIMARY KEY,

    ReportingYear SMALLINT NOT NULL,
    ReportingMonth TINYINT NULL,
    ReportingPeriodStart DATE NULL,
    IsAnnualSummary BIT NOT NULL,

    CreatedUtc DATETIME2(0) NOT NULL
        CONSTRAINT DF_Core_ReportingPeriod_CreatedUtc
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_Core_ReportingPeriod_Month
        CHECK
        (
            ReportingMonth IS NULL
            OR ReportingMonth BETWEEN 1 AND 12
        ),

    CONSTRAINT CK_Core_ReportingPeriod_Annual
        CHECK
        (
            (
                IsAnnualSummary = 1
                AND ReportingMonth IS NULL
                AND ReportingPeriodStart IS NULL
            )
            OR
            (
                IsAnnualSummary = 0
                AND ReportingMonth IS NOT NULL
                AND ReportingPeriodStart IS NOT NULL
            )
        )
);
GO

ALTER TABLE core.ReportingPeriod
ADD ReportingPeriodNaturalKey AS
(
    CONCAT(
        ReportingYear,
        '|',
        COALESCE(
            CONVERT(VARCHAR(2), ReportingMonth),
            'ANNUAL'
        )
    )
) PERSISTED;
GO

CREATE UNIQUE INDEX UX_Core_ReportingPeriod_NaturalKey
    ON core.ReportingPeriod(ReportingPeriodNaturalKey);
GO
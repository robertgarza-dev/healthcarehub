USE HealthcareHub;
GO

CREATE OR ALTER VIEW analytics.vwMedicareEnrollmentPipelineStatus
AS
SELECT
    ds.DataSourceId,
    ds.SourceName,
    ds.SourceAgency,
    ds.SourceUrl,
    ds.Program,
    ds.GeographicGrain,
    ds.ReportingCadence,

    pr.PipelineRunId,
    pr.ReportingPeriod,
    pr.StartedUtc,
    pr.CompletedUtc,
    pr.Status,

    pr.RowsRead,
    pr.RowsInserted,
    pr.RowsUpdated,
    pr.RowsRejected,

    pr.ErrorMessage
FROM ops.DataSource ds
CROSS APPLY
(
    SELECT TOP (1)
        p.PipelineRunId,
        p.ReportingPeriod,
        p.StartedUtc,
        p.CompletedUtc,
        p.Status,
        p.RowsRead,
        p.RowsInserted,
        p.RowsUpdated,
        p.RowsRejected,
        p.ErrorMessage
    FROM ops.PipelineRun p
    WHERE p.DataSourceId = ds.DataSourceId
    ORDER BY
        COALESCE(p.CompletedUtc, p.StartedUtc) DESC,
        p.PipelineRunId DESC
) pr
WHERE ds.SourceName = 'Medicare Monthly Enrollment';
GO
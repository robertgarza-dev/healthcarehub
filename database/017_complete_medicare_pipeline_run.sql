USE HealthcareHub;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @PipelineRunId BIGINT = 2;
DECLARE @SourceFileId BIGINT = 2;

DECLARE @RowsRead BIGINT;
DECLARE @RowsInserted BIGINT;

------------------------------------------------------------
-- 1. Get validated counts
------------------------------------------------------------

SELECT
    @RowsRead = COUNT_BIG(*)
FROM raw.MedicareMonthlyEnrollment
WHERE PipelineRunId = @PipelineRunId;

SELECT
    @RowsInserted = COUNT_BIG(*)
FROM core.MedicareEnrollment
WHERE PipelineRunId = @PipelineRunId;

IF @RowsRead <> @RowsInserted
BEGIN
    THROW 50001, 'RAW/CORE row-count validation failed.', 1;
END;

------------------------------------------------------------
-- 2. Complete pipeline run
------------------------------------------------------------

UPDATE ops.PipelineRun
SET
    CompletedUtc = SYSUTCDATETIME(),
    Status = 'Success',
    RowsRead = @RowsRead,
    RowsInserted = @RowsInserted,
    RowsUpdated = 0,
    RowsRejected = 0,
    ErrorMessage = NULL
WHERE PipelineRunId = @PipelineRunId;

IF @@ROWCOUNT <> 1
BEGIN
    THROW 50002, 'PipelineRunId was not found.', 1;
END;

------------------------------------------------------------
-- 3. Mark source file processed
------------------------------------------------------------

UPDATE ops.SourceFile
SET
    IsProcessed = 1,
    ProcessedUtc = SYSUTCDATETIME()
WHERE SourceFileId = @SourceFileId
  AND PipelineRunId = @PipelineRunId;

IF @@ROWCOUNT <> 1
BEGIN
    THROW 50003, 'SourceFile update failed.', 1;
END;

------------------------------------------------------------
-- 4. Return final status
------------------------------------------------------------

SELECT
    pr.PipelineRunId,
    pr.ReportingPeriod,
    pr.StartedUtc,
    pr.CompletedUtc,
    pr.Status,
    pr.RowsRead,
    pr.RowsInserted,
    pr.RowsUpdated,
    pr.RowsRejected,

    sf.SourceFileId,
    sf.FileName,
    sf.IsProcessed,
    sf.ProcessedUtc
FROM ops.PipelineRun pr
JOIN ops.SourceFile sf
    ON sf.PipelineRunId = pr.PipelineRunId
WHERE pr.PipelineRunId = @PipelineRunId;
GO
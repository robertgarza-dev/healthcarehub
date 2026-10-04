USE HealthcareHub;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SourceFileId BIGINT = 2;
DECLARE @DataSourceId INT;
DECLARE @PipelineRunId BIGINT;
DECLARE @ReportingPeriodStart DATE;
DECLARE @ReportingPeriodEnd DATE;
DECLARE @ReportingPeriod NVARCHAR(50);
DECLARE @IsProcessed BIT;
DECLARE @ExistingPipelineRunId BIGINT;

BEGIN TRY
    BEGIN TRANSACTION;

    ------------------------------------------------------------
    -- 1. Validate the source file
    ------------------------------------------------------------

    SELECT
        @DataSourceId = DataSourceId,
        @ReportingPeriodStart = ReportingPeriodStart,
        @ReportingPeriodEnd = ReportingPeriodEnd,
        @IsProcessed = IsProcessed,
        @ExistingPipelineRunId = PipelineRunId
    FROM ops.SourceFile
    WHERE SourceFileId = @SourceFileId;

    IF @DataSourceId IS NULL
    BEGIN
        THROW 50001, 'SourceFileId was not found in ops.SourceFile.', 1;
    END;

    IF @IsProcessed = 1
    BEGIN
        THROW 50002, 'Source file has already been processed.', 1;
    END;

    IF @ExistingPipelineRunId IS NOT NULL
    BEGIN
        THROW 50003, 'Source file is already associated with a PipelineRun.', 1;
    END;

    IF @ReportingPeriodStart IS NULL
       OR @ReportingPeriodEnd IS NULL
    BEGIN
        THROW 50004, 'Source file does not have a complete reporting period.', 1;
    END;

    ------------------------------------------------------------
    -- 2. Build a readable reporting-period label
    ------------------------------------------------------------

    SET @ReportingPeriod =
        CONCAT(
            CONVERT(char(10), @ReportingPeriodStart, 23),
            ' to ',
            CONVERT(char(10), @ReportingPeriodEnd, 23)
        );

    ------------------------------------------------------------
    -- 3. Create the new pipeline run
    ------------------------------------------------------------

    INSERT INTO ops.PipelineRun
    (
        DataSourceId,
        ReportingPeriod,
        Status
    )
    VALUES
    (
        @DataSourceId,
        @ReportingPeriod,
        'Running'
    );

    SET @PipelineRunId =
        CONVERT(BIGINT, SCOPE_IDENTITY());

    ------------------------------------------------------------
    -- 4. Link the source file to the pipeline run
    ------------------------------------------------------------

    UPDATE ops.SourceFile
    SET PipelineRunId = @PipelineRunId
    WHERE SourceFileId = @SourceFileId;

    COMMIT TRANSACTION;

    ------------------------------------------------------------
    -- 5. Return the run information
    ------------------------------------------------------------

    SELECT
        sf.SourceFileId,
        sf.DataSourceId,
        sf.FileName,
        sf.ReportingPeriodStart,
        sf.ReportingPeriodEnd,
        sf.SourceModifiedDate,
        sf.IsProcessed,
        sf.PipelineRunId,

        pr.ReportingPeriod,
        pr.StartedUtc,
        pr.Status
    FROM ops.SourceFile sf
    JOIN ops.PipelineRun pr
        ON pr.PipelineRunId = sf.PipelineRunId
    WHERE sf.SourceFileId = @SourceFileId;

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO
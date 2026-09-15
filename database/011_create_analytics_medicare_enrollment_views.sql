USE HealthcareHub;
GO

CREATE OR ALTER VIEW analytics.vwMedicareEnrollmentNationalTrend
AS
SELECT
    rp.ReportingPeriodId,
    rp.ReportingYear,
    rp.ReportingMonth,
    rp.ReportingPeriodStart,

    me.TotalBeneficiaries,
    me.OriginalMedicareBeneficiaries,
    me.MedicareAdvantageAndOtherBeneficiaries,

    CAST(
        me.MedicareAdvantageAndOtherBeneficiaries * 100.0
        / NULLIF(me.TotalBeneficiaries, 0)
        AS DECIMAL(6,2)
    ) AS MedicareAdvantagePercent,

    me.PrescriptionDrugBeneficiaries,
    me.DualEligibleBeneficiaries,

    me.HasSuppressedValues,
    me.SuppressedValueCount,

    me.PipelineRunId
FROM core.MedicareEnrollment me
JOIN core.Geography g
    ON g.GeographyId = me.GeographyId
JOIN core.ReportingPeriod rp
    ON rp.ReportingPeriodId = me.ReportingPeriodId
WHERE
    g.GeographyType = 'National'
    AND rp.IsAnnualSummary = 0;
GO


CREATE OR ALTER VIEW analytics.vwMedicareEnrollmentStateTrend
AS
SELECT
    g.StateCode,
    g.StateName,

    rp.ReportingPeriodId,
    rp.ReportingYear,
    rp.ReportingMonth,
    rp.ReportingPeriodStart,

    me.TotalBeneficiaries,
    me.OriginalMedicareBeneficiaries,
    me.MedicareAdvantageAndOtherBeneficiaries,

    CAST(
        me.MedicareAdvantageAndOtherBeneficiaries * 100.0
        / NULLIF(me.TotalBeneficiaries, 0)
        AS DECIMAL(6,2)
    ) AS MedicareAdvantagePercent,

    me.PrescriptionDrugBeneficiaries,
    me.DualEligibleBeneficiaries,

    me.HasSuppressedValues,
    me.SuppressedValueCount,

    me.PipelineRunId
FROM core.MedicareEnrollment me
JOIN core.Geography g
    ON g.GeographyId = me.GeographyId
JOIN core.ReportingPeriod rp
    ON rp.ReportingPeriodId = me.ReportingPeriodId
WHERE
    g.GeographyType = 'State'
    AND rp.IsAnnualSummary = 0;
GO


CREATE OR ALTER VIEW analytics.vwMedicareEnrollmentCountyLatest
AS
SELECT
    g.StateCode,
    g.StateName,
    g.CountyName,
    g.FipsCode,

    rp.ReportingYear,
    rp.ReportingMonth,
    rp.ReportingPeriodStart,

    me.TotalBeneficiaries,
    me.OriginalMedicareBeneficiaries,
    me.MedicareAdvantageAndOtherBeneficiaries,

    CAST(
        me.MedicareAdvantageAndOtherBeneficiaries * 100.0
        / NULLIF(me.TotalBeneficiaries, 0)
        AS DECIMAL(6,2)
    ) AS MedicareAdvantagePercent,

    me.PrescriptionDrugBeneficiaries,
    me.DualEligibleBeneficiaries,

    me.HasSuppressedValues,
    me.SuppressedValueCount,

    me.PipelineRunId
FROM core.MedicareEnrollment me
JOIN core.Geography g
    ON g.GeographyId = me.GeographyId
JOIN core.ReportingPeriod rp
    ON rp.ReportingPeriodId = me.ReportingPeriodId
WHERE
    g.GeographyType = 'County'
    AND rp.IsAnnualSummary = 0
    AND rp.ReportingPeriodStart =
    (
        SELECT MAX(rp2.ReportingPeriodStart)
        FROM core.ReportingPeriod rp2
        WHERE rp2.IsAnnualSummary = 0
    );
GO


CREATE OR ALTER VIEW analytics.vwMedicareEnrollmentLatestSnapshot
AS
SELECT
    g.GeographyType,
    g.StateCode,
    g.StateName,
    g.CountyName,
    g.FipsCode,

    rp.ReportingYear,
    rp.ReportingMonth,
    rp.ReportingPeriodStart,

    me.TotalBeneficiaries,
    me.OriginalMedicareBeneficiaries,
    me.MedicareAdvantageAndOtherBeneficiaries,

    CAST(
        me.MedicareAdvantageAndOtherBeneficiaries * 100.0
        / NULLIF(me.TotalBeneficiaries, 0)
        AS DECIMAL(6,2)
    ) AS MedicareAdvantagePercent,

    me.PrescriptionDrugBeneficiaries,
    me.DualEligibleBeneficiaries,

    me.HasSuppressedValues,
    me.SuppressedValueCount,

    me.PipelineRunId
FROM core.MedicareEnrollment me
JOIN core.Geography g
    ON g.GeographyId = me.GeographyId
JOIN core.ReportingPeriod rp
    ON rp.ReportingPeriodId = me.ReportingPeriodId
WHERE
    rp.IsAnnualSummary = 0
    AND rp.ReportingPeriodStart =
    (
        SELECT MAX(rp2.ReportingPeriodStart)
        FROM core.ReportingPeriod rp2
        WHERE rp2.IsAnnualSummary = 0
    );
GO
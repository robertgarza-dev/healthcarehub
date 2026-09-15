USE HealthcareHub;
GO

INSERT INTO core.ReportingPeriod
(
    ReportingYear,
    ReportingMonth,
    ReportingPeriodStart,
    IsAnnualSummary
)
SELECT DISTINCT
    s.ReportingYear,
    s.ReportingMonth,
    s.ReportingPeriodStart,
    s.IsAnnualSummary
FROM stage.MedicareMonthlyEnrollment s
WHERE NOT EXISTS
(
    SELECT 1
    FROM core.ReportingPeriod rp
    WHERE
        rp.ReportingYear = s.ReportingYear
        AND ISNULL(rp.ReportingMonth, 0) =
            ISNULL(s.ReportingMonth, 0)
        AND rp.IsAnnualSummary = s.IsAnnualSummary
);
GO
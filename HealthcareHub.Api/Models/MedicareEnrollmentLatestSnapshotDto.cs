namespace HealthcareHub.Api.Models;

public sealed class MedicareEnrollmentLatestSnapshotDto
{
    public string GeographyType { get; init; } = string.Empty;
    public string? StateCode { get; init; }
    public string? StateName { get; init; }
    public string? CountyName { get; init; }
    public string? FipsCode { get; init; }

    public short ReportingYear { get; init; }
    public byte ReportingMonth { get; init; }
    public DateTime ReportingPeriodStart { get; init; }

    public long? TotalBeneficiaries { get; init; }
    public long? OriginalMedicareBeneficiaries { get; init; }
    public long? MedicareAdvantageAndOtherBeneficiaries { get; init; }
    public decimal? MedicareAdvantagePercent { get; init; }

    public long? PrescriptionDrugBeneficiaries { get; init; }
    public long? DualEligibleBeneficiaries { get; init; }

    public bool HasSuppressedValues { get; init; }
    public short SuppressedValueCount { get; init; }

    public long PipelineRunId { get; init; }
}
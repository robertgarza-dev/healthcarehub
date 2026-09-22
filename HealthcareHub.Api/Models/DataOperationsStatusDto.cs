namespace HealthcareHub.Api.Models;

public sealed class DataOperationsStatusDto
{
    public int DataSourceId { get; init; }

    public string SourceName { get; init; } = string.Empty;
    public string SourceAgency { get; init; } = string.Empty;
    public string SourceUrl { get; init; } = string.Empty;

    public string? Program { get; init; }
    public string? GeographicGrain { get; init; }
    public string? ReportingCadence { get; init; }

    public long PipelineRunId { get; init; }
    public string? ReportingPeriod { get; init; }

    public DateTime StartedUtc { get; init; }
    public DateTime? CompletedUtc { get; init; }

    public string Status { get; init; } = string.Empty;

    public long? RowsRead { get; init; }
    public long? RowsInserted { get; init; }
    public long? RowsUpdated { get; init; }
    public long? RowsRejected { get; init; }

    public string? ErrorMessage { get; init; }
}
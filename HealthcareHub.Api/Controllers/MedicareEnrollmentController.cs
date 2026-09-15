using HealthcareHub.Api.Data;
using HealthcareHub.Api.Models;
using Microsoft.AspNetCore.Mvc;

namespace HealthcareHub.Api.Controllers;

[ApiController]
[Route("api/medicare/enrollment")]
public sealed class MedicareEnrollmentController : ControllerBase
{
    private readonly MedicareEnrollmentRepository _repository;

    public MedicareEnrollmentController(
        MedicareEnrollmentRepository repository)
    {
        _repository = repository;
    }

    [HttpGet("national")]
    [ProducesResponseType(
        typeof(IEnumerable<MedicareEnrollmentNationalTrendDto>),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
            IEnumerable<MedicareEnrollmentNationalTrendDto>>>
        GetNationalTrend()
    {
        var results =
            await _repository.GetNationalTrendAsync();

        return Ok(results);
    }
    
    [HttpGet("states/{stateCode}")]
    [ProducesResponseType(
        typeof(IEnumerable<MedicareEnrollmentStateTrendDto>),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
            IEnumerable<MedicareEnrollmentStateTrendDto>>>
        GetStateTrend(string stateCode)
    {
        var results =
            await _repository.GetStateTrendAsync(stateCode);

        return Ok(results);
    }
    
    [HttpGet("counties/{stateCode}")]
    [ProducesResponseType(
        typeof(IEnumerable<MedicareEnrollmentCountyLatestDto>),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
            IEnumerable<MedicareEnrollmentCountyLatestDto>>>
        GetCountiesLatest(string stateCode)
    {
        var results =
            await _repository.GetCountiesLatestAsync(stateCode);

        return Ok(results);
    }
    
    [HttpGet("latest")]
    [ProducesResponseType(
        typeof(IEnumerable<MedicareEnrollmentLatestSnapshotDto>),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
            IEnumerable<MedicareEnrollmentLatestSnapshotDto>>>
        GetLatestSnapshot()
    {
        var results =
            await _repository.GetLatestSnapshotAsync();

        return Ok(results);
    }
}
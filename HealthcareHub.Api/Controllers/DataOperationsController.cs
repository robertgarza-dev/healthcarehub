using HealthcareHub.Api.Data;
using HealthcareHub.Api.Models;
using Microsoft.AspNetCore.Mvc;

namespace HealthcareHub.Api.Controllers;

[ApiController]
[Route("api/data-operations")]
public sealed class DataOperationsController : ControllerBase
{
    private readonly DataOperationsRepository _repository;

    public DataOperationsController(
        DataOperationsRepository repository)
    {
        _repository = repository;
    }

    [HttpGet("medicare-enrollment")]
    [ProducesResponseType(
        typeof(DataOperationsStatusDto),
        StatusCodes.Status200OK)]
    [ProducesResponseType(
        StatusCodes.Status404NotFound)]
    public async Task<ActionResult<DataOperationsStatusDto>>
        GetMedicareEnrollmentStatus()
    {
        var result =
            await _repository.GetMedicareEnrollmentStatusAsync();

        if (result is null)
        {
            return NotFound();
        }

        return Ok(result);
    }
}
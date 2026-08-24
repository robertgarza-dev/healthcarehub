using Microsoft.AspNetCore.Mvc;

namespace HealthcareHub.Api.Controllers;

[ApiController]
[Route("api/[controller]")]

public class HealthController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new
        {
            status = "ok",
            application = "HealthcareHub.Api",
            timestampUtc = DateTime.UtcNow
        });
    }
}
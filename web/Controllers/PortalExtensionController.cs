using System.Net;
using System.Security.Claims;
using KagishoConnect.Portal.Models;
using KagishoConnect.Portal.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace KagishoConnect.Portal.Controllers;

[ApiController]
[Authorize(Roles="Admin,Teacher")]
[Route("api/extended")]
[ResponseCache(NoStore=true,Location=ResponseCacheLocation.None)]
public sealed class PortalExtensionController(PortalExtensionService service):ControllerBase
{
    private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private async Task<string> Token()=>await HttpContext.GetTokenAsync("access_token")??throw new SchoolDataException("Please sign in again.",HttpStatusCode.Unauthorized);
    private IActionResult Fail(SchoolDataException e)=>StatusCode((int)(e.Status??HttpStatusCode.BadRequest),new{error=e.Message});
    private async Task<IActionResult> Act(Func<Task<object>> f)
    {
        try{return Ok(await f());}
        catch(SchoolDataException e){return Fail(e);}
    }
    [HttpGet("bootstrap")]
    public Task<IActionResult> Bootstrap(CancellationToken ct)=>Act(async()=>await service.Dashboard(await Token(),ct));
    [Authorize(Roles="Admin")][HttpGet("guardian-requests")]
    public Task<IActionResult> GuardianRequests(CancellationToken ct)=>
        Act(async()=>await service.GuardianRequests(await Token(),ct));
    [Authorize(Roles="Admin")][HttpPut("learners/{id:guid}/birthdate")][ValidateAntiForgeryToken]
    public Task<IActionResult> SetBirthdate(string id,[FromBody] BirthdateInput input,CancellationToken ct)=>
        Act(async()=>await service.SetLearnerBirthdate(id,input.Date,await Token(),ct));
    [Authorize(Roles="Admin")][HttpPost("guardian-requests/{id:guid}/review")][ValidateAntiForgeryToken]
    public Task<IActionResult> ReviewGuardian(string id,[FromBody] GuardianReviewInput input,CancellationToken ct)=>
        Act(async()=>await service.ReviewGuardianRequest(id,input.Approve,input.Note,await Token(),ct));
    [HttpPost("attendance/summary")][ValidateAntiForgeryToken]
    public Task<IActionResult> AttendanceSummary([FromBody] AttendanceSummaryInput input,CancellationToken ct)=>
        Act(async()=>await service.AttendanceAnalytics(input.Start,input.End,input.Grade,input.ClassId,await Token(),ct));
    [HttpPut("announcements/{id:guid}")][ValidateAntiForgeryToken]
    public Task<IActionResult> UpdateAnnouncement(string id,[FromBody] AnnouncementChange input,CancellationToken ct)=>
        Act(async()=>await service.UpdateAnnouncement(id,input.Announcement,input.Status,await Token(),ct));
    [HttpPatch("announcements/{id:guid}/status")][ValidateAntiForgeryToken]
    public Task<IActionResult> AnnouncementStatus(string id,[FromBody] StatusInput input,CancellationToken ct)=>
        Act(async()=>await service.ChangeAnnouncementStatus(id,input.Status,await Token(),ct));
    [Authorize(Roles="Admin")][HttpDelete("announcements/{id:guid}")][ValidateAntiForgeryToken]
    public Task<IActionResult> DeleteAnnouncement(string id,CancellationToken ct)=>Act(async()=>await service.DeleteAnnouncement(id,await Token(),ct));
    [HttpPut("events/{id:guid}")][ValidateAntiForgeryToken]
    public Task<IActionResult> UpdateEvent(string id,[FromBody] EventEdit input,CancellationToken ct)=>Act(async()=>await service.UpdateEvent(id,input,await Token(),ct));
    [Authorize(Roles="Admin")][HttpDelete("events/{id:guid}")][ValidateAntiForgeryToken]
    public Task<IActionResult> DeleteEvent(string id,CancellationToken ct)=>Act(async()=>await service.DeleteEvent(id,await Token(),ct));
    [Authorize(Roles="Admin")][HttpPut("learners/{id:guid}")][ValidateAntiForgeryToken]
    public Task<IActionResult> UpdateLearner(string id,[FromBody] LearnerEdit input,CancellationToken ct)=>Act(async()=>await service.UpdateLearner(id,input,await Token(),ct));
    [Authorize(Roles="Admin")][HttpDelete("learners/{learner:guid}/guardians/{guardian:guid}")][ValidateAntiForgeryToken]
    public Task<IActionResult> UnlinkGuardian(string learner,string guardian,CancellationToken ct)=>Act(async()=>{await service.RemoveGuardian(learner,guardian,await Token(),ct);return new{saved=true};});
    [Authorize(Roles="Admin")][HttpPost("terms")][ValidateAntiForgeryToken]
    public Task<IActionResult> CreateTerm([FromBody] TermInput input,CancellationToken ct)=>Act(async()=>await service.AddTerm(input,await Token(),ct));
    [HttpPost("reports")][ValidateAntiForgeryToken]
    public Task<IActionResult> CreateReport([FromBody] ReportInput input,CancellationToken ct)=>Act(async()=>await service.CreateReport(input,Actor,await Token(),ct));
    [HttpPost("reports/{id:guid}/marks")][ValidateAntiForgeryToken]
    public Task<IActionResult> SaveReportMark(string id,[FromBody] ReportMarkInput input,CancellationToken ct)=>Act(async()=>await service.SaveReportMark(id,input,await Token(),ct));
    [HttpPatch("reports/{id:guid}/publication")][ValidateAntiForgeryToken]
    public Task<IActionResult> ReportStatus(string id,[FromBody] ReportPublishInput input,CancellationToken ct)=>Act(async()=>{
        if(!input.Published&&!User.IsInRole("Admin"))throw new SchoolDataException("Only administrators can unpublish report cards.",HttpStatusCode.Forbidden);
        return await service.SetReportStatus(id,input.Published,input.Comment,await Token(),ct);
    });
    [HttpPost("messages/{guardianId:guid}/read")][ValidateAntiForgeryToken]
    public Task<IActionResult> MarkRead(string guardianId,CancellationToken ct)=>Act(async()=>{await service.SaveRead(guardianId,Actor,await Token(),ct);return new{saved=true};});
    [HttpPost("documents/upload")][ValidateAntiForgeryToken][RequestSizeLimit(16 * 1024 * 1024)]
    public Task<IActionResult> Upload([FromForm] IFormFile file,[FromForm] string title,[FromForm] string description,
        [FromForm] string category,[FromForm] string grade,[FromForm] bool published,CancellationToken ct)=>
        Act(async()=>{await service.UploadDocument(file,title,description??"",category,grade,published,Actor,await Token(),ct);return new{saved=true};});
    [HttpGet("documents/{id:guid}/download")]
    public async Task<IActionResult> Download(string id,CancellationToken ct)
    {
        try{var result=await service.DownloadDocument(id,await Token(),ct);
            Response.Headers["X-Content-Type-Options"]="nosniff";
            return File(result.Data,"application/octet-stream",result.Name);
        }catch(SchoolDataException e){return Fail(e);}
    }
    [HttpGet("documents/{id:guid}/preview")]
    public async Task<IActionResult> Preview(string id,CancellationToken ct)
    {
        try{var result=await service.DownloadDocument(id,await Token(),ct);
            if(result.Mime is not ("application/pdf" or "image/jpeg" or "image/png"))
                return BadRequest(new{error="Only PDF and image previews are available. Download other file types."});
            Response.Headers["X-Content-Type-Options"]="nosniff";
            Response.Headers["Content-Security-Policy"]="sandbox";
            return File(result.Data,result.Mime);
        }catch(SchoolDataException e){return Fail(e);}
    }
    [HttpPatch("documents/{id:guid}/publication")][ValidateAntiForgeryToken]
    public Task<IActionResult> DocumentStatus(string id,[FromBody] PublishInput input,CancellationToken ct)=>Act(async()=>await service.SetDocumentPublished(id,input.Published,await Token(),ct));
    [HttpDelete("documents/{id:guid}")][ValidateAntiForgeryToken]
    public Task<IActionResult> DeleteDocument(string id,CancellationToken ct)=>Act(async()=>{await service.DeleteDocument(id,await Token(),ct);return new{saved=true};});
}
public sealed record AnnouncementChange(AnnouncementRequest Announcement,string Status);

public sealed record AttendanceSummaryInput(string Start,string End,string Grade,string ClassId);

public sealed record BirthdateInput(string Date);
public sealed record GuardianReviewInput(bool Approve,string Note);

using System.Net;
using System.Security.Claims;
using KagishoConnect.Portal.Models;
using KagishoConnect.Portal.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace KagishoConnect.Portal.Controllers;

[ApiController]
[Authorize(Roles="Teacher,Admin")]
[Route("api")]
[ResponseCache(NoStore=true,Location=ResponseCacheLocation.None)]
public sealed class PortalApiController(SupabaseSchoolService school):ControllerBase
{
    private Guid Actor=>Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    private async Task<string> Token()=>await HttpContext.GetTokenAsync("access_token") ?? throw new SchoolDataException("Your login session has expired.",HttpStatusCode.Unauthorized);
    private IActionResult Error(SchoolDataException ex)=>StatusCode((int)(ex.Status??HttpStatusCode.BadRequest),new{error=ex.Message});
    [HttpGet("bootstrap")]
    public async Task<IActionResult> Bootstrap(CancellationToken ct)
    {
        try
        {
            var data=await school.LoadStaffDashboard(await Token(),ct);
            return Ok(new{user=new{name=User.Identity?.Name,role=User.FindFirstValue(ClaimTypes.Role),id=Actor},data});
        }
        catch(SchoolDataException e){return Error(e);}
    }
    [HttpPost("attendance")][ValidateAntiForgeryToken]
    public async Task<IActionResult> Attendance([FromBody] AttendanceSubmission input,CancellationToken ct)
    {
        try{return Ok(await school.SubmitRoll(input,await Token(),ct));}catch(SchoolDataException e){return Error(e);}
    }
    [HttpPost("marks")][ValidateAntiForgeryToken]
    public async Task<IActionResult> Mark([FromBody] MarkUpdate input,CancellationToken ct)
    {
        try{await school.SaveMark(input,Actor,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    [HttpPost("announcements")][ValidateAntiForgeryToken]
    public async Task<IActionResult> Announcement([FromBody] AnnouncementRequest input,CancellationToken ct)
    {
        try{await school.Publish(input,Actor,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    [HttpPost("events")][ValidateAntiForgeryToken]
    public async Task<IActionResult> Event([FromBody] EventRequest input,CancellationToken ct)
    {
        try{await school.AddEvent(input.Title,input.Description,input.Date,input.Grade,input.Category,input.Time,Actor,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    [HttpPost("messages")][ValidateAntiForgeryToken]
    public async Task<IActionResult> Message([FromBody] MessageRequest input,CancellationToken ct)
    {
        try{await school.SendMessage(input.GuardianId,input.Text,Actor,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    [Authorize(Roles="Admin")][HttpGet("admin/directory")]
    public async Task<IActionResult> Directory(CancellationToken ct)
    {
        try
        {
            var jwt=await Token();
            return Ok(new{parents=await school.AdminParents(jwt,ct),links=await school.AdminLinks(jwt,ct),assignments=await school.AdminAssignments(jwt,ct)});
        }catch(SchoolDataException e){return Error(e);}
    }
    [Authorize(Roles="Admin")][HttpPost("admin/classes")][ValidateAntiForgeryToken]
    public async Task<IActionResult> NewClass([FromBody] NewClassRequest input,CancellationToken ct)
    {
        try{await school.AddClass(input.Name,input.Grade,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    [Authorize(Roles="Admin")][HttpPost("admin/learners")][ValidateAntiForgeryToken]
    public async Task<IActionResult> NewLearner([FromBody] NewLearnerRequest input,CancellationToken ct)
    {
        try{await school.AddLearner(input.Name,input.ClassId,input.AdmissionNumber,input.BirthDate,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    [Authorize(Roles="Admin")][HttpPost("admin/link-guardian")][ValidateAntiForgeryToken]
    public async Task<IActionResult> NewGuardianLink([FromBody] ParentLinkRequest input,CancellationToken ct)
    {
        try{await school.LinkGuardian(input.UserId,input.LearnerId,Actor,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    [Authorize(Roles="Admin")][HttpPost("admin/assign-teacher")][ValidateAntiForgeryToken]
    public async Task<IActionResult> NewStaffClass([FromBody] TeacherClassRequest input,CancellationToken ct)
    {
        try{await school.AssignTeacher(input.UserId,input.ClassId,await Token(),ct);return Ok(new{saved=true});}catch(SchoolDataException e){return Error(e);}
    }
    public sealed record EventRequest(string Title,string Description,string Date,string Grade,string Category="General",string Time="");
    public sealed record NewClassRequest(string Name,int Grade);
    public sealed record NewLearnerRequest(string Name,string ClassId,string AdmissionNumber,string BirthDate);
    public sealed record ParentLinkRequest(string UserId,string LearnerId);
    public sealed record TeacherClassRequest(string UserId,string ClassId);
}

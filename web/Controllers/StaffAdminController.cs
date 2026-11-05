using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Security.Claims;
using KagishoConnect.Portal.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace KagishoConnect.Portal.Controllers;

[ApiController]
[Authorize(Roles="Admin")]
[Route("api/admin/staff")]
[ResponseCache(NoStore=true,Location=ResponseCacheLocation.None)]
public sealed class StaffAdminController(SupabaseAuthService auth):ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        try {return Ok(new {staff=await auth.ListStaffAsync(ct)});}
        catch(PortalAuthException){return StatusCode(503,new{error="The staff directory is temporarily unavailable."});}
    }
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Invite([FromBody] InviteRequest data,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(data.Name)||data.Name.Trim().Length is <2 or >100||
           string.IsNullOrWhiteSpace(data.Email)||data.Email.Length>254||!new EmailAddressAttribute().IsValid(data.Email)||
           data.Role is not ("Teacher" or "Admin"))
            return BadRequest(new{error="Provide a full name, valid email and staff role."});
        try
        {
            var invitedBy=Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var callback=Url.Action("Activate","Portal",null,Request.Scheme)!;
            var staff=await auth.InviteStaffAsync(data.Email.Trim().ToLowerInvariant(),data.Name.Trim(),data.Role,callback,invitedBy,ct);
            return Ok(new{staff,message="Invitation sent. The staff member should open the email and choose a password."});
        }
        catch(PortalAuthException ex)
        {
            var status=ex.Status==HttpStatusCode.BadRequest||ex.Status==HttpStatusCode.Conflict?409:503;
            return StatusCode(status,new{error=status==409?"This email may already be registered or invited. Please check the staff directory.":ex.Message});
        }
        catch(HttpRequestException){return StatusCode(503,new{error="Unable to contact the identity service."});}
    }
    [HttpPost("{userId:guid}/status")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Status(Guid userId,[FromBody] StatusRequest input,CancellationToken ct)
    {
        if(userId==Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!)) return BadRequest(new{error="You cannot change your own staff status."});
        try
        {
            var members=await auth.ListStaffAsync(ct);
            var member=members.FirstOrDefault(s=>s.UserId==userId);
            if(member==null)return NotFound(new{error="Staff member not found."});
            if(!input.Active && member.Role=="Admin" && members.Count(s=>s.Role=="Admin"&&s.Active)<=1)
                return BadRequest(new{error="The school must keep at least one active administrator."});
            var updated=await auth.SetActiveAsync(userId,input.Active,ct);
            return Ok(new {staff=updated});
        }
        catch(PortalAuthException){return StatusCode(503,new{error="Could not update this staff account."});}
        catch(HttpRequestException){return StatusCode(503,new{error="Unable to contact the identity service."});}
    }
    public sealed record InviteRequest(string Email,string Name,string Role);
    public sealed record StatusRequest(bool Active);
}

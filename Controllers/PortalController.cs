using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using KagishoConnect.Portal.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace KagishoConnect.Portal.Controllers;

[ResponseCache(NoStore=true,Location=ResponseCacheLocation.None)]
public sealed class PortalController(SupabaseAuthService auth):Controller
{
    [AllowAnonymous]
    [HttpGet("login")]
    public IActionResult Login() => User.Identity?.IsAuthenticated==true ? Redirect("/") : View();

    [AllowAnonymous]
    [HttpPost("login")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> LoginPost(string email,string password,CancellationToken ct)
    {
        if(!ValidEmail(email)||string.IsNullOrEmpty(password))
        {ModelState.AddModelError("","Enter your email address and password.");return View("Login");}
        try
        {
            var session=await auth.SignInAsync(email.Trim(),password,ct);
            if (session.Role is not ("Admin" or "Teacher"))
            {ModelState.AddModelError("","The website is for school staff only. Parents should use the Kagisho Connect mobile app."); return View("Login");}
            await SignIn(session);
            return LocalRedirect("/");
        }
        catch(PortalAuthException ex){ModelState.AddModelError("",SafeError(ex));return View("Login");}
        catch(HttpRequestException){ModelState.AddModelError("","Unable to contact Supabase. Please try again.");return View("Login");}
    }

    [AllowAnonymous]
    [HttpGet("register")]
    public IActionResult Register()=>Redirect("/login");

    [AllowAnonymous]
    [HttpGet("activate")]
    public IActionResult Activate()=>View();

    [AllowAnonymous]
    [HttpPost("activate")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ActivatePost(string accessToken,string password,string confirmPassword,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(accessToken)||string.IsNullOrEmpty(password)||password.Length<12||password!=confirmPassword)
        {ModelState.AddModelError("","Open your invitation link and enter matching passwords of at least 12 characters.");return View("Activate");}
        try
        {
            var userId=await auth.ValidateUserAsync(accessToken,ct);
            var staff=await auth.StaffByUserAsync(userId,ct);
            if(staff is null || !staff.Active) throw new PortalAuthException("No active staff invitation was found for this account.");
            await auth.SetPasswordAsync(accessToken,password,ct);
            ViewBag.Success="Password created. You can now sign in using your email address.";
            return View("Activate");
        }
        catch(PortalAuthException ex){ModelState.AddModelError("",SafeError(ex));return View("Activate");}
        catch(HttpRequestException){ModelState.AddModelError("","Unable to contact Supabase. Please try again.");return View("Activate");}
    }

    [AllowAnonymous]
    [HttpGet("forgot-password")]
    public IActionResult Forgot()=>View();

    [AllowAnonymous]
    [HttpPost("forgot-password")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ForgotPost(string email,CancellationToken ct)
    {
        if(ValidEmail(email))
        {
            try {await auth.SendPasswordResetAsync(email.Trim(),Url.Action("Reset","Portal",null,Request.Scheme)!,ct);}
            catch(PortalAuthException){} catch(HttpRequestException){}
        }
        ViewBag.Success="If this email belongs to an account, password reset instructions will be sent.";
        return View("Forgot");
    }

    [AllowAnonymous]
    [HttpGet("reset-password")]
    public IActionResult Reset()=>View();

    [AllowAnonymous]
    [HttpPost("reset-password")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ResetPost(string accessToken,string password,string confirmPassword,CancellationToken ct)
    {
        if(string.IsNullOrWhiteSpace(accessToken)||string.IsNullOrEmpty(password)||password.Length<12||password!=confirmPassword)
        {ModelState.AddModelError("","Use your reset link and matching passwords of at least 12 characters.");return View("Reset");}
        try {await auth.SetPasswordAsync(accessToken,password,ct);ViewBag.Success="Password updated. Please sign in.";}
        catch(PortalAuthException ex){ModelState.AddModelError("",SafeError(ex));}
        catch(HttpRequestException){ModelState.AddModelError("","Unable to contact Supabase.");}
        return View("Reset");
    }

    [AllowAnonymous]
    [HttpGet("denied")]
    public IActionResult Denied()=>Content("Access denied. Your account does not have permission to open this section.");

    [AllowAnonymous]
    [HttpGet("error")]
    public IActionResult Error()=>Content("A request could not be completed. Please contact your school administrator.");

    [Authorize]
    [HttpGet("/")]
    public IActionResult Index()=>View();

    [Authorize]
    [HttpPost("logout")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        var access=(await HttpContext.AuthenticateAsync()).Properties?.GetTokenValue("access_token");
        if(!string.IsNullOrWhiteSpace(access)) await auth.SignOutAsync(access,ct);
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return LocalRedirect("/login");
    }
    private Task SignIn(PortalSession session)=>HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,PortalPrincipal.FromSession(session),PortalPrincipal.Properties(session));
    private static bool ValidEmail(string? email) => !string.IsNullOrWhiteSpace(email)&&email.Length<=254&&new EmailAddressAttribute().IsValid(email);
    private static string SafeError(PortalAuthException ex)=>ex.Status==System.Net.HttpStatusCode.BadRequest||ex.Status==System.Net.HttpStatusCode.Unauthorized
        ? "Unable to complete your request. Check your details or email confirmation and try again." : ex.Message;
}

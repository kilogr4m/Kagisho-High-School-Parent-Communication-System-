using System.Security.Claims;
using KagishoConnect.Portal.Services;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllersWithViews();
builder.Services.AddAntiforgery(o => o.HeaderName="X-CSRF-TOKEN");
builder.Services.AddHttpClient<SupabaseSchoolService>(client=>client.Timeout=TimeSpan.FromSeconds(25));
builder.Services.AddHttpClient<PortalExtensionService>(client=>client.Timeout=TimeSpan.FromSeconds(45));
builder.Services.AddHttpClient<SupabaseAuthService>(client=>client.Timeout=TimeSpan.FromSeconds(20));
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options=>
    {
        options.LoginPath="/login";
        options.AccessDeniedPath="/denied";
        options.Cookie.Name="__Host-KagishoPortal";
        options.Cookie.HttpOnly=true;
        options.Cookie.SecurePolicy=CookieSecurePolicy.Always;
        options.Cookie.SameSite=SameSiteMode.Lax;
        options.Cookie.Path="/";
        options.ExpireTimeSpan=TimeSpan.FromHours(4);
        options.SlidingExpiration=false;
        options.Events.OnValidatePrincipal = async context =>
        {
            var service=context.HttpContext.RequestServices.GetRequiredService<SupabaseAuthService>();
            try
            {
                string? access=context.Properties?.GetTokenValue("access_token");
                string? refresh=context.Properties?.GetTokenValue("refresh_token");
                string? expiry=context.Properties?.GetTokenValue("expires_at");
                if(string.IsNullOrWhiteSpace(access) || string.IsNullOrWhiteSpace(refresh) ||
                   !DateTimeOffset.TryParse(expiry,out var ends))
                { context.RejectPrincipal(); return; }
                Guid userId=Guid.Parse(context.Principal!.FindFirstValue(ClaimTypes.NameIdentifier) ?? "");
                PortalSession? newSession=null;
                if (ends<=DateTimeOffset.UtcNow.AddSeconds(60))
                {
                    newSession=await service.RefreshAsync(refresh,context.HttpContext.RequestAborted);
                    if(newSession.UserId!=userId) {context.RejectPrincipal();return;}
                    access=newSession.AccessToken;
                    PortalPrincipal.SetTokens(context.Properties!,newSession);
                    context.ShouldRenew=true;
                }
                var verifiedId=await service.ValidateUserAsync(access!,context.HttpContext.RequestAborted);
                if(verifiedId!=userId) {context.RejectPrincipal();return;}
                var staff=await service.StaffByUserAsync(userId,context.HttpContext.RequestAborted);
                if(staff!=null && !staff.Active) {context.RejectPrincipal();return;}
                var role=staff?.Role ?? "Parent";
                if(role is not ("Admin" or "Teacher")) {context.RejectPrincipal();return;}
                var currentRole=context.Principal!.FindFirstValue(ClaimTypes.Role);
                if(staff == null)
                { context.RejectPrincipal(); return; } // Revoked staff cannot silently fall back to parent.
                if(role!=currentRole || (staff != null && staff.FullName!=context.Principal.Identity?.Name))
                {
                    string name=staff?.FullName ?? context.Principal.Identity?.Name ?? "Parent";
                    string email=staff?.Email ?? context.Principal.FindFirstValue(ClaimTypes.Email) ?? "";
                    context.ReplacePrincipal(PortalPrincipal.FromIdentity(userId,name,email,role));
                    context.ShouldRenew=true;
                }
            }
            catch(Exception ex) when(ex is PortalAuthException or HttpRequestException or TaskCanceledException or FormatException)
            { context.RejectPrincipal(); }
        };
    });
builder.Services.AddAuthorization();
var app=builder.Build();
if(!app.Environment.IsDevelopment()) {app.UseExceptionHandler("/error");app.UseHsts();}
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapControllerRoute(name:"default",pattern:"{controller=Portal}/{action=Index}/{id?}");
app.Run();

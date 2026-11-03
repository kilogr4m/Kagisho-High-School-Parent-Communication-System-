using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace KagishoConnect.Portal.Services;

public static class PortalPrincipal
{
    public static ClaimsPrincipal FromSession(PortalSession session) => FromIdentity(session.UserId,session.Name,session.Email,session.Role);
    public static ClaimsPrincipal FromIdentity(Guid id,string name,string email,string role)
    {
        var claims=new[]
        {
            new Claim(ClaimTypes.NameIdentifier,id.ToString()),
            new Claim(ClaimTypes.Name,name),
            new Claim(ClaimTypes.Email,email),
            new Claim(ClaimTypes.Role,role)
        };
        return new ClaimsPrincipal(new ClaimsIdentity(claims,CookieAuthenticationDefaults.AuthenticationScheme));
    }
    public static AuthenticationProperties Properties(PortalSession session)
    {
        var properties = new AuthenticationProperties {IsPersistent=false,AllowRefresh=true,ExpiresUtc=DateTimeOffset.UtcNow.AddHours(4)};
        SetTokens(properties,session);
        return properties;
    }
    public static void SetTokens(AuthenticationProperties properties,PortalSession session) => properties.StoreTokens(new[]
    {
        new AuthenticationToken {Name="access_token",Value=session.AccessToken},
        new AuthenticationToken {Name="refresh_token",Value=session.RefreshToken},
        new AuthenticationToken {Name="expires_at",Value=session.ExpiresAt.ToString("O",CultureInfo.InvariantCulture)}
    });
}

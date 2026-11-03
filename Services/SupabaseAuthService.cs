using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace KagishoConnect.Portal.Services;

// All privileged Supabase calls remain on this ASP.NET server.
public sealed class SupabaseAuthService(HttpClient client, IConfiguration configuration)
{
    private readonly string _url = (configuration["Supabase:Url"] ?? "").TrimEnd('/');
    private readonly string _publishable = configuration["Supabase:PublishableKey"] ?? "";
    private readonly string _secret = configuration["Supabase:SecretKey"] ?? "";
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public bool Ready => Uri.TryCreate(_url, UriKind.Absolute, out var uri) && uri.Scheme == "https" &&
                         uri.Host.EndsWith(".supabase.co", StringComparison.OrdinalIgnoreCase) &&
                         !string.IsNullOrWhiteSpace(_publishable) && !string.IsNullOrWhiteSpace(_secret);

    private HttpRequestMessage Request(HttpMethod method, string path, bool privileged, string? bearer = null, object? payload = null)
    {
        if (!Ready) throw new PortalAuthException("The school portal has not been connected to Supabase yet.");
        var request = new HttpRequestMessage(method, _url + path);
        string key = privileged ? _secret : _publishable;
        request.Headers.TryAddWithoutValidation("apikey", key);
        if (!string.IsNullOrWhiteSpace(bearer)) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearer);
        // Legacy service_role JWT needs an Authorization header. New sb_secret_* keys must not be passed as Bearer tokens.
        else if (privileged && key.StartsWith("eyJ", StringComparison.Ordinal))
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
        if (payload != null) request.Content = new StringContent(JsonSerializer.Serialize(payload, Json), Encoding.UTF8, "application/json");
        return request;
    }

    private async Task<JsonElement> SendAsync(HttpMethod method, string path, bool privileged = false, string? bearer = null,
        object? payload = null, CancellationToken ct = default)
    {
        using var request = Request(method, path, privileged, bearer, payload);
        using var response = await client.SendAsync(request, ct);
        var contents = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
        {
            string message = "The identity service could not complete your request.";
            try
            {
                using var error = JsonDocument.Parse(contents);
                var obj = error.RootElement;
                message = Field(obj,"msg") ?? Field(obj,"message") ?? Field(obj,"error_description") ?? message;
            }
            catch (JsonException) { }
            throw new PortalAuthException(message, response.StatusCode);
        }
        if (string.IsNullOrWhiteSpace(contents)) return JsonDocument.Parse("{}").RootElement.Clone();
        using var result = JsonDocument.Parse(contents);
        return result.RootElement.Clone();
    }
    private static string? Field(JsonElement element, string key) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    private static JsonElement Child(JsonElement element, string key) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(key, out var value) ? value : default;
    private static string Require(JsonElement element, string key) => Field(element, key) ?? throw new PortalAuthException("The identity service returned an incomplete response.");

    public async Task<PortalSession> SignInAsync(string email, string password, CancellationToken ct = default)
    {
        var response = await SendAsync(HttpMethod.Post, "/auth/v1/token?grant_type=password", payload: new {email, password}, ct:ct);
        return await ReadSessionAsync(response, ct);
    }
    public async Task<PortalSession> RefreshAsync(string refreshToken, CancellationToken ct = default)
    {
        var response = await SendAsync(HttpMethod.Post, "/auth/v1/token?grant_type=refresh_token", payload: new {refresh_token=refreshToken}, ct:ct);
        return await ReadSessionAsync(response, ct);
    }
    private async Task<PortalSession> ReadSessionAsync(JsonElement response, CancellationToken ct)
    {
        var user = Child(response,"user");
        var id = Guid.Parse(Require(user,"id"));
        var email = Require(user,"email");
        var staff = await StaffByUserAsync(id, ct);
        if (staff != null && !staff.Active) throw new PortalAuthException("Your staff account is currently inactive. Contact the school administrator.", HttpStatusCode.Forbidden);
        var role = staff?.Role ?? "Parent";
        var meta = Child(user,"user_metadata");
        var name = staff?.FullName ?? Field(meta,"full_name") ?? email.Split('@')[0];
        var expiresIn = Child(response,"expires_in");
        var seconds = expiresIn.ValueKind == JsonValueKind.Number && expiresIn.TryGetInt32(out var n) ? n : 3600;
        return new PortalSession(id, email, name, role, Require(response,"access_token"),Require(response,"refresh_token"),DateTimeOffset.UtcNow.AddSeconds(Math.Max(60,seconds)));
    }
    public async Task<Guid> ValidateUserAsync(string accessToken, CancellationToken ct = default)
    {
        var response = await SendAsync(HttpMethod.Get, "/auth/v1/user", bearer:accessToken, ct:ct);
        return Guid.Parse(Require(response,"id"));
    }
    public async Task SignUpParentAsync(string email, string password, string fullName, string redirectUrl, CancellationToken ct = default)
    {
        // The server never grants roles based on user-editable metadata.
        await SendAsync(HttpMethod.Post, "/auth/v1/signup?redirect_to="+Uri.EscapeDataString(redirectUrl),payload:new {email,password,data=new {full_name=fullName}},ct:ct);
    }
    public async Task SendPasswordResetAsync(string email, string redirectUrl, CancellationToken ct = default)
    {
        var path = "/auth/v1/recover?redirect_to=" + Uri.EscapeDataString(redirectUrl);
        await SendAsync(HttpMethod.Post,path,payload:new {email},ct:ct);
    }
    public async Task SetPasswordAsync(string accessToken, string password, CancellationToken ct = default)
    {
        await SendAsync(HttpMethod.Put,"/auth/v1/user",bearer:accessToken,payload:new {password},ct:ct);
    }
    public async Task SignOutAsync(string accessToken, CancellationToken ct = default)
    {
        try { await SendAsync(HttpMethod.Post,"/auth/v1/logout",bearer:accessToken,payload:new { },ct:ct); }
        catch (PortalAuthException) { /* Clear local cookie even if remote signout fails. */ }
    }
    public async Task<StaffRecord?> StaffByUserAsync(Guid userId, CancellationToken ct = default)
    {
        var json = await SendAsync(HttpMethod.Get,"/rest/v1/kc_portal_staff?user_id=eq."+userId+"&select=user_id,email,full_name,role,is_active,created_at&limit=1", true,ct:ct);
        if (json.ValueKind != JsonValueKind.Array || json.GetArrayLength()==0) return null;
        return ParseStaff(json[0]);
    }
    public async Task<List<StaffRecord>> ListStaffAsync(CancellationToken ct = default)
    {
        var rows=await SendAsync(HttpMethod.Get,"/rest/v1/kc_portal_staff?select=user_id,email,full_name,role,is_active,created_at&order=created_at.desc",true,ct:ct);
        return rows.ValueKind==JsonValueKind.Array?rows.EnumerateArray().Select(ParseStaff).ToList():[];
    }
    private static StaffRecord ParseStaff(JsonElement x) => new(Guid.Parse(Require(x,"user_id")),Require(x,"email"),Require(x,"full_name"),Require(x,"role"),Child(x,"is_active").GetBoolean(),Field(x,"created_at")??"");
    public async Task<StaffRecord> InviteStaffAsync(string email,string name,string role,string redirectUrl,Guid invitedBy,CancellationToken ct=default)
    {
        var response = await SendAsync(HttpMethod.Post,"/auth/v1/invite?redirect_to="+Uri.EscapeDataString(redirectUrl),true,
            payload:new{email,data=new{full_name=name}},ct:ct);
        var user = Child(response,"user");
        var id=Guid.Parse(Field(user,"id")??Require(response,"id"));
        var staff=await SendAsync(HttpMethod.Post,"/rest/v1/kc_portal_staff?select=user_id,email,full_name,role,is_active,created_at",true,
            bearer:null,payload:new {user_id=id,email,full_name=name,role,is_active=true,invited_by=invitedBy},ct:ct,preferReturn:true);
        if(staff.ValueKind!=JsonValueKind.Array||staff.GetArrayLength()==0)throw new PortalAuthException("Invitation sent, but the staff record could not be saved. Contact an administrator.");
        return ParseStaff(staff[0]);
    }
    // For PostgREST writes, Prefer: return=representation returns created/updated row, rather than an empty response.
    private async Task<JsonElement> SendAsync(HttpMethod method,string path,bool privileged,string? bearer,object? payload,CancellationToken ct,bool preferReturn)
    {
        using var request=Request(method,path,privileged,bearer,payload);
        if(preferReturn)request.Headers.TryAddWithoutValidation("Prefer","return=representation");
        using var response=await client.SendAsync(request,ct);
        var contents=await response.Content.ReadAsStringAsync(ct);
        if(!response.IsSuccessStatusCode)
        {
            string message="Could not update the staff directory.";
            try {using var doc=JsonDocument.Parse(contents);message=Field(doc.RootElement,"message")??message;} catch(JsonException){}
            throw new PortalAuthException(message,response.StatusCode);
        }
        using var result=JsonDocument.Parse(string.IsNullOrWhiteSpace(contents)?"[]":contents);
        return result.RootElement.Clone();
    }
    public async Task<StaffRecord> SetActiveAsync(Guid staffId,bool active,CancellationToken ct=default)
    {
        var rows=await SendAsync(new HttpMethod("PATCH"),"/rest/v1/kc_portal_staff?user_id=eq."+staffId+"&select=user_id,email,full_name,role,is_active,created_at",true,
            bearer:null,payload:new {is_active=active},ct:ct,preferReturn:true);
        if(rows.ValueKind!=JsonValueKind.Array || rows.GetArrayLength()==0)throw new PortalAuthException("Staff member not found.",HttpStatusCode.NotFound);
        return ParseStaff(rows[0]);
    }
}

public sealed record PortalSession(Guid UserId,string Email,string Name,string Role,string AccessToken,string RefreshToken,DateTimeOffset ExpiresAt);
public sealed record StaffRecord(Guid UserId,string Email,string FullName,string Role,bool Active,string CreatedAt);
public sealed class PortalAuthException(string message,HttpStatusCode? status=null): Exception(message)
{
    public HttpStatusCode? Status { get; }=status;
}

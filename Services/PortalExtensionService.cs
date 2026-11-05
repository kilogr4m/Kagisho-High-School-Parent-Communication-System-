using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using KagishoConnect.Portal.Models;

namespace KagishoConnect.Portal.Services;

// New portal-only features. All requests carry the logged-in staff's Supabase JWT:
// RLS still controls row access; no service-role secret is used here.
public sealed class PortalExtensionService(HttpClient client,IConfiguration config)
{
    private readonly string _root = (config["Supabase:Url"]??"").TrimEnd('/');
    private readonly string _key = config["Supabase:PublishableKey"]??"";
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private const int MaxUpload = 15 * 1024 * 1024;

    private HttpRequestMessage Request(HttpMethod method,string path,string token,object? payload=null)
    {
        if(!_root.StartsWith("https://",StringComparison.OrdinalIgnoreCase)||string.IsNullOrWhiteSpace(_key))
            throw new SchoolDataException("Supabase connection is not configured.");
        var req=new HttpRequestMessage(method,_root+path);
        req.Headers.TryAddWithoutValidation("apikey",_key);
        req.Headers.Authorization=new AuthenticationHeaderValue("Bearer",token);
        if(payload!=null) req.Content=new StringContent(JsonSerializer.Serialize(payload,Json),Encoding.UTF8,"application/json");
        return req;
    }
    private static string ErrorText(string text)
    {
        try { using var json=JsonDocument.Parse(text);
            var root=json.RootElement;
            if(root.TryGetProperty("message",out var m)&&m.ValueKind==JsonValueKind.String)return m.GetString()??"Request failed.";
            if(root.TryGetProperty("error",out var e)&&e.ValueKind==JsonValueKind.String)return e.GetString()??"Request failed.";
        } catch(JsonException) {}
        return "The database operation failed. Please check permissions and connection.";
    }
    private async Task<JsonElement> Send(HttpMethod method,string path,string token,object? body=null,bool rows=false,CancellationToken ct=default)
    {
        using var req=Request(method,path,token,body);
        if(rows) req.Headers.TryAddWithoutValidation("Prefer","return=representation,resolution=merge-duplicates");
        using var res=await client.SendAsync(req,ct);
        var txt=await res.Content.ReadAsStringAsync(ct);
        if(!res.IsSuccessStatusCode)throw new SchoolDataException(ErrorText(txt),res.StatusCode);
        using var json=JsonDocument.Parse(string.IsNullOrWhiteSpace(txt)?"[]":txt);
        return json.RootElement.Clone();
    }
    private async Task<int> Count(string table,string key,string token,CancellationToken ct)
    {
        using var req=Request(HttpMethod.Get,$"/rest/v1/{table}?select={key}&limit=1",token);
        req.Headers.TryAddWithoutValidation("Prefer","count=exact");
        using var res=await client.SendAsync(req,ct);
        if(!res.IsSuccessStatusCode)throw new SchoolDataException(ErrorText(await res.Content.ReadAsStringAsync(ct)),res.StatusCode);
        if(res.Content.Headers.TryGetValues("Content-Range",out var values))
        {
            var header=values.FirstOrDefault()??"";
            if(int.TryParse(header.Split('/').LastOrDefault(),out var count))return count;
        }
        throw new SchoolDataException("The database did not return an exact row count.");
    }
    private static string Enc(string s)=>Uri.EscapeDataString(s);
    private Task<JsonElement> Get(string table,string select,string query,string token,CancellationToken ct) =>
        Send(HttpMethod.Get,$"/rest/v1/{table}?select={select}&{query}",token,ct:ct);
    private static JsonElement One(JsonElement rows)
    {
        if(rows.ValueKind!=JsonValueKind.Array||rows.GetArrayLength()==0)throw new SchoolDataException("Record not found or access denied.",HttpStatusCode.NotFound);
        return rows[0];
    }
    private static string Field(JsonElement row,string field)=>row.TryGetProperty(field,out var v)&&v.ValueKind==JsonValueKind.String?v.GetString()??"":"";
    private static Guid ID(string id)
    {
        if(!Guid.TryParse(id,out var parsed))throw new SchoolDataException("Invalid record ID.",HttpStatusCode.BadRequest);
        return parsed;
    }
    private static void Required(string text,int min,int max,string label)
    {
        if(string.IsNullOrWhiteSpace(text)||text.Trim().Length<min||text.Trim().Length>max)
            throw new SchoolDataException($"{label} must contain {min}–{max} characters.",HttpStatusCode.BadRequest);
    }
    private static int? Grade(string s)
    {
        if(s=="all")return null;
        if(!int.TryParse(s,out var g)||g is <8 or >12)throw new SchoolDataException("Choose a valid grade.");
        return g;
    }
    public async Task<JsonElement> AttendanceAnalytics(string start,string end,string grade,string classId,string jwt,CancellationToken ct)
    {
        if(!DateOnly.TryParse(start,out var from)||!DateOnly.TryParse(end,out var to)||to<from||to.DayNumber-from.DayNumber>730)
            throw new SchoolDataException("Enter a valid date range of at most two years.");
        Guid? cls=classId=="all"?null:ID(classId);
        return await Send(HttpMethod.Post,"/rest/v1/rpc/kc_school_attendance_summary",jwt,
            new{p_start=from.ToString("yyyy-MM-dd"),p_end=to.ToString("yyyy-MM-dd"),p_grade=Grade(grade),p_class_id=cls},ct:ct);
    }
    public async Task<object> GuardianRequests(string jwt,CancellationToken ct)
    {
        var requests=await Get("kc_guardian_requests",
            "id,parent_id,child_name,child_birth_date,status,review_note,created_at,reviewed_at,learner_id",
            "order=created_at.desc&limit=100",jwt,ct);
        var dates=await Get("kc_learner_birthdates","learner_id,birth_date","limit=500",jwt,ct);
        return new {requests,birthdates=dates};
    }
    public async Task<JsonElement> SetLearnerBirthdate(string learnerId,string date,string jwt,CancellationToken ct)
    {
        var id=ID(learnerId);
        if(!DateOnly.TryParseExact(date,"yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture,System.Globalization.DateTimeStyles.None,out var dob)||dob.Year<1990||dob>DateOnly.FromDateTime(DateTime.UtcNow))
            throw new SchoolDataException("Enter a valid learner date of birth (YYYY-MM-DD).");
        var value=dob.ToString("yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture);
        var saved=await Send(HttpMethod.Post,"/rest/v1/kc_learner_birthdates?on_conflict=learner_id",jwt,
            new{learner_id=id,birth_date=value,updated_at=DateTimeOffset.UtcNow},true,ct);
        var row=One(saved);
        if(Field(row,"birth_date")!=value)
            throw new SchoolDataException("The school could not confirm that the date of birth was saved.");
        return row;
    }
    public async Task<object> ReviewGuardianRequest(string requestId,bool approve,string note,string jwt,CancellationToken ct)
    {
        var id=ID(requestId);
        if((note??"").Length>500)throw new SchoolDataException("Review note is too long.");
        // The V6 SQL function reviews the request and adds the guardian link atomically.
        // Its return value alone is not proof that the status persisted: re-read it.
        await Send(HttpMethod.Post,"/rest/v1/rpc/kc_review_guardian_request",jwt,
            new {p_request_id=id,p_approve=approve,p_note=note??""},ct:ct);
        var rows=await Get("kc_guardian_requests","id,parent_id,status,learner_id",
            $"id=eq.{id}&limit=1",jwt,ct);
        var row=One(rows);
        var status=Field(row,"status");
        var expected=approve?"approved":"rejected";
        if(status!=expected)
            throw new SchoolDataException("Review status was not confirmed. Refresh the request list before retrying.");
        var learnerId=Field(row,"learner_id");
        if(approve)
        {
            if(!Guid.TryParse(learnerId,out _))
                throw new SchoolDataException("Approval is missing the verified learner link. Contact the administrator.");
            var parentId=Field(row,"parent_id");
            var links=await Get("kc_guardian_links","learner_id,user_id",
                $"learner_id=eq.{ID(learnerId)}&user_id=eq.{ID(parentId)}&limit=1",jwt,ct);
            One(links); // RLS-checked link must actually exist.
        }
        return new {status,learnerId=approve?learnerId:null,id};
    }
    public async Task<object> Dashboard(string jwt,CancellationToken ct)
    {
        var docs=await Get("kc_documents","id,title,description,category,grade,published,original_name,storage_path,mime_type,file_size,uploaded_by,created_at","order=created_at.desc&limit=500",jwt,ct);
        var terms=await Get("kc_terms","id,academic_year,term_no,starts_on,ends_on","order=academic_year.desc,term_no.asc",jwt,ct);
        var reports=await Get("kc_report_cards","id,learner_id,term_id,status,teacher_comment,published_at,updated_at","order=updated_at.desc&limit=1000",jwt,ct);
        var marks=await Get("kc_report_marks","id,report_id,subject,percentage","order=subject.asc&limit=3000",jwt,ct);
        var reads=await Get("kc_message_reads","guardian_id,last_read_at","",jwt,ct);
        var audit=await Get("kc_audit_logs","id,actor,table_name,record_id,operation,occurred_at","order=occurred_at.desc&limit=200",jwt,ct);
        var learnerCount=await Count("kc_learners","id",jwt,ct);
        var parentCount=await Count("kc_parent_profiles","user_id",jwt,ct);
        var documentCount=await Count("kc_documents","id",jwt,ct);
        var reportCount=await Count("kc_report_cards","id",jwt,ct);
        return new{documents=docs,terms,reports,reportMarks=marks,messageReads=reads,audit,
            totals=new{learnerCount,parentCount,documentCount,reportCount}};
    }
    public Task<JsonElement> UpdateAnnouncement(string id,AnnouncementRequest m,string status,string jwt,CancellationToken ct)
    {
        ID(id);Required(m.Title,2,120,"Title");Required(m.Body,2,4000,"Message");
        if(m.Priority is not ("Normal" or "Important" or "Urgent")||status is not ("draft" or "published" or "archived"))
            throw new SchoolDataException("Invalid announcement priority or status.");
        return Change("kc_announcements",id,new{title=m.Title.Trim(),body=m.Body.Trim(),grade=Grade(m.Grade),priority=m.Priority,status},jwt,ct);
    }
    public Task<JsonElement> ChangeAnnouncementStatus(string id,string status,string jwt,CancellationToken ct)
    {
        ID(id);
        if(status is not ("draft" or "published" or "archived"))throw new SchoolDataException("Invalid announcement status.");
        return Change("kc_announcements",id,new{status},jwt,ct);
    }
    public Task<JsonElement> DeleteAnnouncement(string id,string jwt,CancellationToken ct)=>Remove("kc_announcements",id,jwt,ct);
    public Task<JsonElement> UpdateEvent(string id,EventEdit m,string jwt,CancellationToken ct)
    {
        ID(id);Required(m.Title,2,120,"Event title");if(m.Description.Length>2000||!DateOnly.TryParse(m.Date,out var d))throw new SchoolDataException("Enter a valid event date and description.");
        if(m.Category.Length>60 || (m.Time.Length>0&&!TimeOnly.TryParse(m.Time,out _)))throw new SchoolDataException("Invalid event category or time.");
        return Change("kc_events",id,new{title=m.Title.Trim(),description=m.Description.Trim(),school_date=d.ToString("yyyy-MM-dd"),grade=Grade(m.Grade),category=m.Category.Trim(),start_time=m.Time.Length>0?m.Time:null},jwt,ct);
    }
    public Task<JsonElement> DeleteEvent(string id,string jwt,CancellationToken ct)=>Remove("kc_events",id,jwt,ct);
    public Task<JsonElement> UpdateLearner(string id,LearnerEdit m,string jwt,CancellationToken ct)
    {
        ID(id);ID(m.ClassId);Required(m.Name,2,100,"Learner name");
        if(m.AdmissionNumber.Trim().Length is >0 and <4 or >32)throw new SchoolDataException("Admission number must be 4–32 characters if provided.");
        return Change("kc_learners",id,new{full_name=m.Name.Trim(),class_id=ID(m.ClassId),
            admission_number=m.AdmissionNumber.Trim().Length==0?null:m.AdmissionNumber.Trim(),active=m.Active},jwt,ct);
    }
    public async Task RemoveGuardian(string learner,string guardian,string jwt,CancellationToken ct)
    {
        ID(learner);ID(guardian);
        var rows=await Send(HttpMethod.Delete,$"/rest/v1/kc_guardian_links?learner_id=eq.{ID(learner)}&user_id=eq.{ID(guardian)}",jwt,rows:true,ct:ct);
        One(rows);
    }
    private async Task<JsonElement> Change(string table,string id,object body,string jwt,CancellationToken ct)
    {
        var rows=await Send(HttpMethod.Patch,$"/rest/v1/{table}?id=eq.{ID(id)}",jwt,body,true,ct);
        return One(rows);
    }
    private async Task<JsonElement> Remove(string table,string id,string jwt,CancellationToken ct)
    {
        var rows=await Send(HttpMethod.Delete,$"/rest/v1/{table}?id=eq.{ID(id)}",jwt,rows:true,ct:ct);
        return One(rows);
    }
    public Task<JsonElement> AddTerm(TermInput t,string jwt,CancellationToken ct)
    {
        if(t.Year is <2020 or >2100||t.Term is <1 or >4||!DateOnly.TryParse(t.Start,out var start)||!DateOnly.TryParse(t.End,out var end)||start>end)
            throw new SchoolDataException("Please enter valid term dates, year and term number.");
        return Send(HttpMethod.Post,"/rest/v1/kc_terms",jwt,new{academic_year=t.Year,term_no=t.Term,starts_on=start.ToString("yyyy-MM-dd"),ends_on=end.ToString("yyyy-MM-dd")},true,ct);
    }
    public Task<JsonElement> CreateReport(ReportInput r,Guid actor,string jwt,CancellationToken ct)
    {
        ID(r.LearnerId);ID(r.TermId);
        if(r.Comment.Length>1500)throw new SchoolDataException("Comment is too long.");
        return Send(HttpMethod.Post,"/rest/v1/kc_report_cards",jwt,new{learner_id=ID(r.LearnerId),term_id=ID(r.TermId),teacher_comment=r.Comment.Trim(),created_by=actor,status="draft"},true,ct);
    }
    public async Task<JsonElement> SaveReportMark(string reportId,ReportMarkInput mark,string jwt,CancellationToken ct)
    {
        ID(reportId);Required(mark.Subject,2,80,"Subject");
        if(mark.Percentage is <0 or >100)throw new SchoolDataException("Mark must be between 0 and 100.");
        var rows=await Send(HttpMethod.Post,"/rest/v1/kc_report_marks?on_conflict=report_id,subject",jwt,
            new{report_id=ID(reportId),subject=mark.Subject.Trim(),percentage=mark.Percentage},true,ct);
        return One(rows);
    }
    public async Task<JsonElement> SetReportStatus(string reportId,bool published,string comment,string jwt,CancellationToken ct)
    {
        ID(reportId);if(comment.Length>1500)throw new SchoolDataException("Comment is too long.");
        if(published)
        {
            var rows=await Get("kc_report_marks","id",$"report_id=eq.{ID(reportId)}&limit=1",jwt,ct);
            if(rows.GetArrayLength()==0)throw new SchoolDataException("Add at least one subject mark before publishing.");
        }
        return await Change("kc_report_cards",reportId,new{status=published?"published":"draft",teacher_comment=comment.Trim(),published_at=published?DateTimeOffset.UtcNow:(DateTimeOffset?)null,updated_at=DateTimeOffset.UtcNow},jwt,ct);
    }
    public async Task SaveRead(string guardianId,Guid actor,string jwt,CancellationToken ct)
    {
        ID(guardianId);
        await Send(HttpMethod.Post,"/rest/v1/kc_message_reads?on_conflict=staff_id,guardian_id",jwt,
            new{staff_id=actor,guardian_id=ID(guardianId),last_read_at=DateTimeOffset.UtcNow},true,ct);
    }

    private static readonly Dictionary<string,(string Mime,byte[]? Signature)> Allowed=new(StringComparer.OrdinalIgnoreCase)
    {
        [".pdf"]=("application/pdf",Encoding.ASCII.GetBytes("%PDF-")),
        [".png"]=("image/png",[137,80,78,71,13,10,26,10]),
        [".jpg"]=("image/jpeg",[255,216,255]),[".jpeg"]=("image/jpeg",[255,216,255]),
        [".docx"]=("application/vnd.openxmlformats-officedocument.wordprocessingml.document",[80,75,3,4]),
        [".xlsx"]=("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",[80,75,3,4]),
        [".doc"]=("application/msword",[208,207,17,224,161,177,26,225]),
        [".xls"]=("application/vnd.ms-excel",[208,207,17,224,161,177,26,225])
    };
    public async Task UploadDocument(IFormFile file,string title,string description,string category,string grade,bool published,Guid actor,string jwt,CancellationToken ct)
    {
        Required(title,2,160,"Document title");Required(category,2,60,"Category");
        if(description.Length>2000||file.Length<1||file.Length>MaxUpload)throw new SchoolDataException("File is empty or exceeds the 15MB upload limit.");
        var ext=Path.GetExtension(file.FileName).ToLowerInvariant();
        if(!Allowed.TryGetValue(ext,out var format))throw new SchoolDataException("Only PDF, Word, Excel, PNG and JPEG documents are allowed.");
        using var ms=new MemoryStream();await file.CopyToAsync(ms,ct);
        var bytes=ms.ToArray();
        if(format.Signature is not null && !bytes.AsSpan().StartsWith(format.Signature))
            throw new SchoolDataException("The file contents do not match its extension.");
        string path=$"{actor:D}/{Guid.NewGuid():N}{ext}";
        using(var upload=Request(HttpMethod.Post,"/storage/v1/object/kagisho-documents/"+path,jwt))
        {
            upload.Content=new ByteArrayContent(bytes);upload.Content.Headers.ContentType=new MediaTypeHeaderValue(format.Mime);
            upload.Headers.TryAddWithoutValidation("x-upsert","false");
            using var response=await client.SendAsync(upload,ct);
            if(!response.IsSuccessStatusCode)throw new SchoolDataException(ErrorText(await response.Content.ReadAsStringAsync(ct)),response.StatusCode);
        }
        try
        {
            await Send(HttpMethod.Post,"/rest/v1/kc_documents",jwt,new{
                title=title.Trim(),description=description.Trim(),category=category.Trim(),grade=Grade(grade),published,
                original_name=Path.GetFileName(file.FileName),storage_path=path,mime_type=format.Mime,file_size=bytes.Length,uploaded_by=actor
            },true,ct);
        }
        catch
        {
            // Best effort removal of orphaned object if metadata INSERT fails.
            try {using var req=Request(HttpMethod.Delete,"/storage/v1/object/kagisho-documents/"+path,jwt);using var _=await client.SendAsync(req,ct);}catch{}
            throw;
        }
    }
    public Task<JsonElement> SetDocumentPublished(string id,bool published,string jwt,CancellationToken ct) =>
        Change("kc_documents",id,new{published},jwt,ct);
    public async Task DeleteDocument(string id,string jwt,CancellationToken ct)
    {
        ID(id);
        var doc=One(await Get("kc_documents","id,storage_path",$"id=eq.{ID(id)}",jwt,ct));
        var path=Field(doc,"storage_path");
        // Metadata delete first: unlisted objects stay private even if later storage deletion fails.
        await Remove("kc_documents",id,jwt,ct);
        using var req=Request(HttpMethod.Delete,"/storage/v1/object/kagisho-documents/"+path,jwt);
        using var response=await client.SendAsync(req,ct);
        if(!response.IsSuccessStatusCode)throw new SchoolDataException("Document removed from the list, but storage cleanup failed. Ask an administrator to check the bucket.");
    }
    public async Task<(byte[] Data,string Mime,string Name)> DownloadDocument(string id,string jwt,CancellationToken ct)
    {
        ID(id);
        var doc=One(await Get("kc_documents","id,storage_path,mime_type,original_name",$"id=eq.{ID(id)}",jwt,ct));
        var path=Field(doc,"storage_path");
        using var req=Request(HttpMethod.Get,"/storage/v1/object/authenticated/kagisho-documents/"+path,jwt);
        using var resp=await client.SendAsync(req,ct);
        if(!resp.IsSuccessStatusCode)throw new SchoolDataException("Unable to download this document.",resp.StatusCode);
        return (await resp.Content.ReadAsByteArrayAsync(ct),Field(doc,"mime_type"),Path.GetFileName(Field(doc,"original_name")));
    }
}
public sealed record EventEdit(string Title,string Description,string Date,string Grade,string Category,string Time="");
public sealed record LearnerEdit(string Name,string ClassId,bool Active,string AdmissionNumber="");
public sealed record TermInput(int Year,int Term,string Start,string End);
public sealed record ReportInput(string LearnerId,string TermId,string Comment);
public sealed record ReportMarkInput(string Subject,decimal Percentage);
public sealed record ReportPublishInput(bool Published,string Comment);
public sealed record StatusInput(string Status);
public sealed record PublishInput(bool Published);

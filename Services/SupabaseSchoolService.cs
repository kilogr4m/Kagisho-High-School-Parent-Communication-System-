using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using KagishoConnect.Portal.Models;

namespace KagishoConnect.Portal.Services;

// All school records travel through the *same* Supabase project as the parent app.
// Requests use the signed-in staff member's JWT: PostgreSQL RLS remains authoritative.
public sealed class SupabaseSchoolService(HttpClient http, IConfiguration configuration)
{
    private readonly string _url=(configuration["Supabase:Url"]??"").TrimEnd('/');
    private readonly string _key=configuration["Supabase:PublishableKey"]??"";
    private static readonly JsonSerializerOptions Json=new(JsonSerializerDefaults.Web);
    public bool Ready=>Uri.TryCreate(_url,UriKind.Absolute,out var uri) && uri.Scheme=="https" && !string.IsNullOrWhiteSpace(_key);
    private async Task<JsonElement> Send(HttpMethod method,string path,string jwt,object? payload=null,bool returnRows=false,CancellationToken ct=default)
    {
        if(!Ready) throw new SchoolDataException("Supabase project URL and publishable key must be configured.");
        if(string.IsNullOrWhiteSpace(jwt)) throw new SchoolDataException("Please sign in again.",HttpStatusCode.Unauthorized);
        using var request=new HttpRequestMessage(method,_url+path);
        request.Headers.TryAddWithoutValidation("apikey",_key);
        request.Headers.Authorization=new AuthenticationHeaderValue("Bearer",jwt);
        if(returnRows)request.Headers.TryAddWithoutValidation("Prefer","return=representation,resolution=merge-duplicates");
        if(payload!=null)request.Content=new StringContent(JsonSerializer.Serialize(payload,Json),Encoding.UTF8,"application/json");
        using var response=await http.SendAsync(request,ct);
        string body=await response.Content.ReadAsStringAsync(ct);
        if(!response.IsSuccessStatusCode)
        {
            string message="School data could not be saved or loaded.";
            try {using var error=JsonDocument.Parse(body); message=Str(error.RootElement,"message")??message;}catch(JsonException){}
            throw new SchoolDataException(message,response.StatusCode);
        }
        using var json=JsonDocument.Parse(string.IsNullOrWhiteSpace(body)?"{}":body);
        return json.RootElement.Clone();
    }
    private static string? Str(JsonElement e,string key) => e.ValueKind==JsonValueKind.Object && e.TryGetProperty(key,out var x) && x.ValueKind==JsonValueKind.String?x.GetString():null;
    private static int Num(JsonElement e,string key) => e.ValueKind==JsonValueKind.Object&&e.TryGetProperty(key,out var x)&&x.TryGetInt32(out var n)?n:0;
    private static bool Bool(JsonElement e,string key) => e.ValueKind==JsonValueKind.Object && e.TryGetProperty(key,out var x)&&x.ValueKind==JsonValueKind.True;
    private static JsonElement[] Arr(JsonElement e) => e.ValueKind==JsonValueKind.Array?e.EnumerateArray().ToArray():[];
    private static string Enc(string text)=>Uri.EscapeDataString(text);
    private Task<JsonElement> Get(string table,string jwt,string select="*",string query="",CancellationToken ct=default)
       =>Send(HttpMethod.Get,"/rest/v1/"+table+"?select="+select+(query.Length>0?"&"+query:""),jwt,ct:ct);

    public async Task<SchoolState> LoadStaffDashboard(string jwt,CancellationToken ct=default)
    {
        // Each query is filtered by RLS. Teachers cannot retrieve unassigned learners.
        var c=await Get("kc_classes",jwt,"id,name,grade", "order=name.asc",ct);
        var l=await Get("kc_learners",jwt,"id,full_name,class_id,admission_number", "active=eq.true&order=full_name.asc",ct);
        var parents=await Get("kc_parent_profiles",jwt,"user_id,full_name,email", "order=full_name.asc",ct);
        var links=await Get("kc_guardian_links",jwt,"user_id,learner_id", "",ct);
        var marks=await Get("kc_marks",jwt,"learner_id,subject,score", "",ct);
        var attendance=await Get("kc_attendance",jwt,"learner_id,school_date,status,updated_at", "order=school_date.desc&limit=1000",ct);
        JsonElement announcements,events;
        try{announcements=await Get("kc_announcements",jwt,"id,title,body,grade,priority,status,created_at", "order=created_at.desc&limit=100",ct);}
        catch(SchoolDataException e) when(e.Status==HttpStatusCode.BadRequest){announcements=await Get("kc_announcements",jwt,"id,title,body,grade,priority,created_at","order=created_at.desc&limit=100",ct);}
        try{events=await Get("kc_events",jwt,"id,title,description,school_date,grade,category,start_time", "order=school_date.asc&limit=200",ct);}
        catch(SchoolDataException e) when(e.Status==HttpStatusCode.BadRequest){events=await Get("kc_events",jwt,"id,title,description,school_date,grade","order=school_date.asc&limit=200",ct);}
        var messages=await Get("kc_messages",jwt,"id,guardian_id,sender_id,body,created_at", "order=created_at.asc&limit=500",ct);
        var state=new SchoolState();
        foreach(var x in Arr(c))state.Classes.Add(new ClassRoom{Id=Str(x,"id")??"",Name=Str(x,"name")??"",Grade=Num(x,"grade"),TeacherId=""});
        foreach(var x in Arr(parents))state.Guardians.Add(new Guardian{Id=Str(x,"user_id")??"",Name=Str(x,"full_name")??""});
        var linkMap=Arr(links).GroupBy(x=>Str(x,"learner_id")??"").ToDictionary(x=>x.Key,x=>x.Select(v=>Str(v,"user_id")??"").Where(v=>v.Length>0).ToList());
        var markMap=Arr(marks).GroupBy(x=>Str(x,"learner_id")??"").ToDictionary(x=>x.Key,x=>x.Select(m=>new SubjectMark{Subject=Str(m,"subject")??"",Score=Num(m,"score")}).ToList());
        foreach(var x in Arr(l))
        {
            var id=Str(x,"id")??"";
            state.Learners.Add(new Learner{Id=id,Name=Str(x,"full_name")??"",AdmissionNumber=Str(x,"admission_number")??"",ClassId=Str(x,"class_id")??"",GuardianId=linkMap.GetValueOrDefault(id)?.FirstOrDefault()??"",GuardianIds=linkMap.GetValueOrDefault(id)??[],Marks=markMap.GetValueOrDefault(id)??[]});
        }
        var learnerClass=state.Learners.ToDictionary(x=>x.Id,x=>x.ClassId);
        foreach(var grp in Arr(attendance).GroupBy(x=>new{Date=Str(x,"school_date")??"",Class=learnerClass.GetValueOrDefault(Str(x,"learner_id")??"","")}))
        {
            if(string.IsNullOrWhiteSpace(grp.Key.Class))continue;
            state.RollCalls.Add(new RollCall{ClassId=grp.Key.Class,Date=grp.Key.Date,UpdatedAt=Str(grp.First(),"updated_at")??"",Statuses=grp.ToDictionary(x=>Str(x,"learner_id")??"",x=>Str(x,"status")??"Present")});
        }
        foreach(var x in Arr(announcements))state.Announcements.Add(new SchoolAnnouncement{Id=Str(x,"id")??"",Title=Str(x,"title")??"",Body=Str(x,"body")??"",Grade= x.TryGetProperty("grade",out var gr) && gr.ValueKind==JsonValueKind.Number ? gr.GetInt32().ToString() : "all",Priority=Str(x,"priority")??"Normal",Status=Str(x,"status")??"published",CreatedAt=Str(x,"created_at")??""});
        foreach(var x in Arr(events))state.Events.Add(new SchoolEvent{Id=Str(x,"id")??"",Title=Str(x,"title")??"",Description=Str(x,"description")??"",SchoolDate=Str(x,"school_date")??"",Category=Str(x,"category")??"General",StartTime=Str(x,"start_time")??"",Grade=x.TryGetProperty("grade",out var eg) && eg.ValueKind==JsonValueKind.Number?eg.GetInt32().ToString():"all"});
        foreach(var x in Arr(messages))state.Messages.Add(new ConversationMessage{Id=Str(x,"id")??"",GuardianId=Str(x,"guardian_id")??"",Sender=Str(x,"sender_id")==Str(x,"guardian_id")?"parent":"staff",Text=Str(x,"body")??"",CreatedAt=Str(x,"created_at")??""});
        return state;
    }
    public async Task<JsonElement> SubmitRoll(AttendanceSubmission data,string jwt,CancellationToken ct=default)
    {
        if(!Guid.TryParse(data.ClassId,out var classId)||!DateOnly.TryParse(data.Date,out var date)||data.Statuses.Count==0 || data.Statuses.Values.Any(s=>s is not ("Present" or "Absent" or "Late" or "Excused")))
            throw new SchoolDataException("Select a class, date and a valid status for every learner.",HttpStatusCode.BadRequest);
        if(data.Statuses.Keys.Any(k=>!Guid.TryParse(k,out _))) throw new SchoolDataException("Invalid learner ID.",HttpStatusCode.BadRequest);
        return await Send(HttpMethod.Post,"/rest/v1/rpc/kc_submit_rollcall",jwt,new{p_class_id=classId,p_school_date=date.ToString("yyyy-MM-dd"),p_statuses=data.Statuses},ct:ct);
    }
    public async Task SaveMark(MarkUpdate input,Guid actor,string jwt,CancellationToken ct=default)
    {
        if(!Guid.TryParse(input.LearnerId,out var learner)||string.IsNullOrWhiteSpace(input.Subject)||input.Subject.Length>80||input.Score is <0 or >100)
            throw new SchoolDataException("Enter a valid subject and mark between 0 and 100.",HttpStatusCode.BadRequest);
        await Send(HttpMethod.Post,"/rest/v1/kc_marks?on_conflict=learner_id,subject",jwt,new{learner_id=learner,subject=input.Subject.Trim(),score=input.Score,updated_by=actor,updated_at=DateTimeOffset.UtcNow},true,ct);
    }
    public async Task Publish(AnnouncementRequest input,Guid actor,string jwt,CancellationToken ct=default)
    {
        if(string.IsNullOrWhiteSpace(input.Title)||input.Title.Length>120||string.IsNullOrWhiteSpace(input.Body)||input.Body.Length>4000||input.Priority is not ("Normal" or "Important" or "Urgent"))
            throw new SchoolDataException("Please complete the announcement fields.",HttpStatusCode.BadRequest);
        int? grade=null;
        if(input.Grade!="all") {if(!int.TryParse(input.Grade,out var g)||g<8||g>12)throw new SchoolDataException("Choose a valid grade.");grade=g;}
        await Send(HttpMethod.Post,"/rest/v1/kc_announcements",jwt,new{title=input.Title.Trim(),body=input.Body.Trim(),grade,priority=input.Priority,created_by=actor},ct:ct);
    }
    public async Task AddEvent(string title,string description,string date,string grade,string category,string time,Guid actor,string jwt,CancellationToken ct=default)
    {
        if(title.Trim().Length is <2 or >120 || description.Length>2000 || category.Trim().Length is <2 or >60 || !DateOnly.TryParse(date,out var day))throw new SchoolDataException("Enter a title, category and date for the school event.");
        int? g=null;
        if(grade!="all") {if(!int.TryParse(grade,out var n)||n is <8 or >12)throw new SchoolDataException("Select a valid grade.");g=n;}
        if(time.Length>0 && !TimeOnly.TryParse(time,out _))throw new SchoolDataException("Enter a valid start time.");
        await Send(HttpMethod.Post,"/rest/v1/kc_events",jwt,new{title=title.Trim(),description=description.Trim(),school_date=day.ToString("yyyy-MM-dd"),grade=g,category=category.Trim(),start_time=time.Length==0?null:time,created_by=actor},ct:ct);
    }
    public async Task SendMessage(string guardianId,string text,Guid actor,string jwt,CancellationToken ct=default)
    {
        if(!Guid.TryParse(guardianId,out var guardian)||string.IsNullOrWhiteSpace(text)||text.Length>1000) throw new SchoolDataException("Choose a parent and enter a message.",HttpStatusCode.BadRequest);
        await Send(HttpMethod.Post,"/rest/v1/kc_messages",jwt,new{guardian_id=guardian,sender_id=actor,body=text.Trim()},ct:ct);
    }
    public async Task<JsonElement> AdminParents(string jwt,CancellationToken ct=default)=>await Get("kc_parent_profiles",jwt,"user_id,full_name,email","order=full_name.asc",ct);
    public async Task<JsonElement> AdminAssignments(string jwt,CancellationToken ct=default)=>await Get("kc_staff_classes",jwt,"user_id,class_id","",ct);
    public async Task<JsonElement> AdminLinks(string jwt,CancellationToken ct=default)=>await Get("kc_guardian_links",jwt,"user_id,learner_id","",ct);
    public async Task AddClass(string name,int grade,string jwt,CancellationToken ct=default)
    {
        if(name.Trim().Length is <2 or >40||grade is <8 or >12)throw new SchoolDataException("Enter a class name and grade 8–12.");
        await Send(HttpMethod.Post,"/rest/v1/kc_classes",jwt,new{name=name.Trim(),grade},ct:ct);
    }
    public async Task AddLearner(string name,string classId,string admissionNumber,string birthDate,string jwt,CancellationToken ct=default)
    {
        if(string.IsNullOrWhiteSpace(name)||name.Trim().Length is <2 or >100||
           !Guid.TryParse(classId,out var cls)||string.IsNullOrWhiteSpace(admissionNumber)||
           admissionNumber.Trim().Length is <4 or >32)
            throw new SchoolDataException("Enter a learner full name, class and unique admission number (4–32 characters).");
        if(!DateOnly.TryParseExact(birthDate,"yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.None,out var dob)||dob.Year<1990||dob>DateOnly.FromDateTime(DateTime.UtcNow))
            throw new SchoolDataException("Enter the learner's verified date of birth (YYYY-MM-DD).");
        // Atomic insert via security-invoker RPC: avoids learners with missing DOBs.
        // Apply database/06_v4_verified_learner_registration.sql first.
        var result=await Send(HttpMethod.Post,"/rest/v1/rpc/kc_register_learner_verified",jwt,
            new {p_name=name.Trim(),p_class_id=cls,p_admission_number=admissionNumber.Trim(),
                p_birth_date=dob.ToString("yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture)},ct:ct);
        if(result.ValueKind!=JsonValueKind.String||!Guid.TryParse(result.GetString(),out _))
            throw new SchoolDataException("The database did not confirm learner registration. Verify the record before retrying.");
    }
    public async Task LinkGuardian(string userId,string learnerId,Guid actor,string jwt,CancellationToken ct=default)
    {
        if(!Guid.TryParse(userId,out var guardian)||!Guid.TryParse(learnerId,out var learner))throw new SchoolDataException("Choose valid parent and learner accounts.");
        await Send(HttpMethod.Post,"/rest/v1/kc_guardian_links",jwt,new{user_id=guardian,learner_id=learner,verified_by=actor},ct:ct);
    }
    public async Task AssignTeacher(string userId,string classId,string jwt,CancellationToken ct=default)
    {
        if(!Guid.TryParse(userId,out var teacher)||!Guid.TryParse(classId,out var cls))throw new SchoolDataException("Choose a teacher and class.");
        await Send(HttpMethod.Post,"/rest/v1/kc_staff_classes",jwt,new{user_id=teacher,class_id=cls},ct:ct);
    }
}
public sealed class SchoolDataException(string message,HttpStatusCode? status=null):Exception(message)
{
    public HttpStatusCode? Status {get;}=status;
}

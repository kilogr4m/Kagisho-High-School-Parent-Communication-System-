namespace KagishoConnect.Portal.Models;

public sealed class SchoolState
{
    public List<Guardian> Guardians { get; set; } = [];
    public List<ClassRoom> Classes { get; set; } = [];
    public List<Learner> Learners { get; set; } = [];
    public List<SchoolAnnouncement> Announcements { get; set; } = [];
    public List<SchoolEvent> Events { get; set; } = [];
    public List<ConversationMessage> Messages { get; set; } = [];
    public List<RollCall> RollCalls { get; set; } = [];
    public List<AttendanceAlert> Alerts { get; set; } = [];
}
public sealed class Guardian
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
}
public sealed class ClassRoom
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string TeacherId { get; set; } = "";
    public int Grade { get; set; }
}
public sealed class SubjectMark
{
    public string Subject { get; set; } = "";
    public int Score { get; set; }
}
public sealed class Learner
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string AdmissionNumber { get; set; } = "";
    public string ClassId { get; set; } = "";
    public string GuardianId { get; set; } = "";
    public List<string> GuardianIds { get; set; } = [];
    public List<SubjectMark> Marks { get; set; } = [];
}
public sealed class SchoolAnnouncement
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string Grade { get; set; } = "all";
    public string Priority { get; set; } = "Normal";
    public string Status { get; set; } = "published";
    public string CreatedAt { get; set; } = "";
}
public sealed class ConversationMessage
{
    public string Id { get; set; } = "";
    public string GuardianId { get; set; } = "";
    public string Sender { get; set; } = "staff";
    public string Text { get; set; } = "";
    public string CreatedAt { get; set; } = "";
}
public sealed class RollCall
{
    public string ClassId { get; set; } = "";
    public string Date { get; set; } = "";
    public Dictionary<string,string> Statuses { get; set; } = [];
    public string SubmittedBy { get; set; } = "";
    public string UpdatedAt { get; set; } = "";
}
public sealed class AttendanceAlert
{
    public string Id { get; set; } = "";
    public string LearnerId { get; set; } = "";
    public string GuardianId { get; set; } = "";
    public string Date { get; set; } = "";
    public string Status { get; set; } = "absent";
    public string CurrentStatus { get; set; } = "Absent";
    public bool IsRead { get; set; }
    public string UpdatedAt { get; set; } = "";
}
public sealed class AttendanceSubmission
{
    public string ClassId { get; set; } = "";
    public string Date { get; set; } = "";
    public Dictionary<string,string> Statuses { get; set; } = [];
}
public sealed class MarkUpdate
{
    public string LearnerId { get; set; } = "";
    public string Subject { get; set; } = "";
    public int Score { get; set; }
}
public sealed class AnnouncementRequest
{
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string Grade { get; set; } = "all";
    public string Priority { get; set; } = "Normal";
}
public sealed class MessageRequest
{
    public string GuardianId { get; set; } = "";
    public string Text { get; set; } = "";
}
public sealed class OperationException(string message) : Exception(message) { }

public sealed class SchoolEvent
{
  public string Id {get;set;} = "";
  public string Title {get;set;} = "";
  public string Description {get;set;} = "";
  public string SchoolDate {get;set;} = "";
  public string Category {get;set;} = "General";
  public string StartTime {get;set;} = "";
  public string Grade {get;set;} = "all";
}

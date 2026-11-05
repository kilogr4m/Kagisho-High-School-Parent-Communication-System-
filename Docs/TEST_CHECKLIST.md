# Kagisho Connect integration acceptance checklist

Use **fictional learners and test emails**. Do not present these as passed until verified.

- [ ] `dotnet restore && dotnet build` succeeds using SDK 9.
- [ ] Flutter SDK `flutter doctor`, `flutter pub get`, `flutter run -d chrome` succeeds.
- [ ] SQL migrations apply without errors to the selected development Supabase project.
- [ ] Supabase Advisor reports no unintended public data exposure.
- [ ] Admin signs in to the ASP.NET portal; parent account is DENIED at `/login`.
- [ ] Parent signs up from Flutter, confirms email and signs in; parent profile is stored.
- [ ] Another parent cannot read the first parent's profile, learner marks, attendance or messages.
- [ ] Admin invites teacher and teacher activates account; teacher can sign in.
- [ ] Teacher cannot open admin staff-management API (403).
- [ ] Admin creates grade 10 class, fictional learner, assigns teacher and verifies parent link.
- [ ] Unassigned teacher cannot read or submit attendance for that class (403/RLS error).
- [ ] Teacher marks every learner Present except one Absent and SUBMITS (no alert before submission).
- [ ] Verified parent sees the absent learner's notification in Flutter after refreshing, not other learners' alerts.
- [ ] Re-submitting identical attendance does not create a second alert.
- [ ] Correcting Absent to Present generates exactly one correction alert; history updates in Flutter.
- [ ] Teacher saves a NEW subject mark and parent sees it in child's profile.
- [ ] Teacher publishes announcement and calendar event; linked parent sees them in Flutter.
- [ ] Parent sends message in Flutter; teacher sees it on website and replies; parent sees reply.
- [ ] Parent with two linked children can switch between them; unlinked child inaccessible.
- [ ] Staff deactivation prevents further sign-in and blocks existing session at validation.
- [ ] Weak internet, disabled email confirmations and expired cookies show comprehensible errors.
- [ ] Configure OS push separately if required: FCM/APNs + device token registration + trusted sender + consent/permission flow.
- [ ] Before real deployment, test rate limits, backup restoration, encryption, security permissions, privacy, POPIA, accessibility and mobile devices.

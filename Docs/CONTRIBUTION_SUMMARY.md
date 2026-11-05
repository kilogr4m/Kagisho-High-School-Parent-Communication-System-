# ELEV8 / Kagisho Connect — ASP.NET + Flutter integration contribution

**Contribution:** Shared school communication system, staff/admin web portal and mobile parent application.

## ASP.NET staff website
Retained the established V3 UI and authentication foundation, removed public parent signup from the site, and added a live Supabase school-data service for the teaching workflows. The administrator can invite/deactivate staff, create classes/learners, verify parent relationships, assign classes to teachers, publish announcements and calendar events. Teachers can manage marks, take roll call and message guardians. All classroom data is intended to be stored in Supabase rather than local demonstration memory.

## Flutter parent app
Created a separate Flutter (Material 3) parent-only application. Parents self-register/sign in with Supabase Auth. Approved guardians can switch between children, see marks/attendance, view school news and events, read attendance alerts, mark alerts as read and send/receive messages. The UI aims for readable type, large controls, friendly copy and low-complexity navigation.

## Shared database/security
Proposed new namespaced PostgreSQL tables with RLS, assignment checks and explicit guardian verification. `kc_submit_rollcall` is a transaction-safe RPC that writes attendance and creates in-app alerts. No secrets are present in the client source. The group must map this proposed schema to its existing Flutter schema before deployment.

## Work still required / honesty
This is code for an integrated MVP, NOT a tested commercial d6 replacement. Neither the .NET/Flutter compilers nor the group's actual Supabase project are available for execution in this environment. Real cross-device tests, production hosting, OS push notifications, document management, accessibility QA, POPIA work and multi-school support are not yet finished.

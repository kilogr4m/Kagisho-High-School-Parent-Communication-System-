# Before connecting to the existing Flutter database

The existing Flutter app is reported to be running with Supabase, but no active Kagisho Supabase project ID, keys or current live schema were available to this build. I deliberately did not alter any external project.

1. Ask the group for the actual Supabase Project URL **and** a read-only list of `public` tables and columns. Do not share secret keys in chat.
2. Back up the project and use a separate development branch/project if possible. Confirm whether the old Flutter app already uses tables such as `USERS`, `ANNOUNCEMENTS`, `GRADE`, or `DOCUMENTS`.
3. Decide whether to map old records into the V4 `kc_*` schema or adapt the queries in `SupabaseSchoolService.cs` and `lib/main.dart` to the old schema. Never maintain two competing sources of truth for learners/parents.
4. Check the existing authentication rules. The website stores staff roles in `kc_portal_staff`; parent registrations use Supabase Auth but are not automatically staff.
5. Only AFTER review, run the migrations from README in a non-production database. Inspect the project SQL editor output and security advisors.
6. Populate fictional data and run the complete cross-app test checklist; do not use actual children's records while testing.

Read-only schema inspection query in Supabase SQL Editor:

```sql
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema='public'
order by table_name, ordinal_position;
```

RLS review query:

```sql
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname='public' and tablename like 'kc_%'
order by tablename;
```

Keep Supabase secret/service-role keys in **server-only** configuration, never in screenshots, chat, repositories, Dart code or `appsettings.json`.

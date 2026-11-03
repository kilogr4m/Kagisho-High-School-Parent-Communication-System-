-- Kagisho Connect: real staff identities and school-admin permissions.
-- Run exactly once in the EXISTING Supabase project's SQL editor after reviewing.
-- Creates a NEW table. Does not modify your Flutter application's existing tables.
-- This is a single-school first-stage directory; multi-school tenant isolation is future work.

create table if not exists public.kc_portal_staff (
    user_id uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    full_name text not null,
    role text not null check(role in ('Admin','Teacher')),
    is_active boolean not null default true,
    invited_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now(),
    constraint kc_staff_email_lowercase check(email = lower(email)),
    constraint kc_staff_fullname_nonempty check(length(trim(full_name)) between 2 and 100)
);
create unique index if not exists kc_portal_staff_email_idx on public.kc_portal_staff (lower(email));
create index if not exists kc_portal_staff_active_idx on public.kc_portal_staff (is_active);

alter table public.kc_portal_staff enable row level security;
-- NO anon/authenticated policies: staff directory is writable/readable only from the trusted ASP.NET server.
revoke all on public.kc_portal_staff from anon, authenticated;
grant select,insert,update,delete on public.kc_portal_staff to service_role;

comment on table public.kc_portal_staff is 'Kagisho Connect staff authorization. Managed server-side by approved school administrators only.';

-- IMPORTANT: Bootstrap the FIRST admin manually after creating their Supabase Auth user:
-- 1. Supabase Dashboard > Authentication > Users > Add user; create admin@your-school-domain and set/confirm password.
-- 2. Check the email is correct, then run the following with YOUR email replacing the placeholder.
-- 3. DO NOT give this command to ordinary school users or include personal emails in the committed migration.
--
-- insert into public.kc_portal_staff(user_id,email,full_name,role,is_active)
-- select id,lower(email),'School Administrator','Admin',true
-- from auth.users where lower(email)=lower('REPLACE-WITH-YOUR-ADMIN-EMAIL@example.com')
-- on conflict(user_id) do nothing;
--
-- Verify bootstrap: select email,role,is_active from public.kc_portal_staff;

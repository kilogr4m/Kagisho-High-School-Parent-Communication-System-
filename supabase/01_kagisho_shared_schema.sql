-- Kagisho Connect V4 / single-school shared data schema.
-- REVIEW before applying to your team's EXISTING Supabase project.
-- This script creates new kc_* tables; it does NOT replace existing school tables.
-- Requires public.kc_portal_staff from the website's Database/01_staff_directory.sql.
-- Never use real learner data in development demonstrations.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.kc_classes (
 id uuid primary key default gen_random_uuid(),
 name text not null unique check (length(trim(name)) between 2 and 40),
 grade int not null check (grade between 1 and 12),
 created_at timestamptz not null default now()
);
create table if not exists public.kc_learners (
 id uuid primary key default gen_random_uuid(),
 full_name text not null check (length(trim(full_name)) between 2 and 100),
 class_id uuid not null references public.kc_classes(id) on delete restrict,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create index if not exists kc_learners_class_idx on public.kc_learners(class_id);
create table if not exists public.kc_parent_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null check (length(trim(full_name)) between 2 and 100),
 email text not null,
 created_at timestamptz not null default now()
);
create table if not exists public.kc_guardian_links (
 user_id uuid not null references public.kc_parent_profiles(user_id) on delete cascade,
 learner_id uuid not null references public.kc_learners(id) on delete cascade,
 verified_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 primary key (user_id, learner_id)
);
create index if not exists kc_guardian_links_learner_idx on public.kc_guardian_links(learner_id);
create table if not exists public.kc_staff_classes (
 user_id uuid not null references public.kc_portal_staff(user_id) on delete cascade,
 class_id uuid not null references public.kc_classes(id) on delete cascade,
 primary key(user_id,class_id)
);
create table if not exists public.kc_marks (
 id uuid primary key default gen_random_uuid(),
 learner_id uuid not null references public.kc_learners(id) on delete cascade,
 subject text not null check(length(trim(subject)) between 2 and 80),
 score integer not null check(score between 0 and 100),
 updated_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now(),
 unique(learner_id,subject)
);
create table if not exists public.kc_attendance (
 learner_id uuid not null references public.kc_learners(id) on delete cascade,
 school_date date not null,
 status text not null check(status in ('Present','Absent','Late','Excused')),
 recorded_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now(),
 primary key(learner_id,school_date)
);
create index if not exists kc_attendance_date_idx on public.kc_attendance(school_date);
create table if not exists public.kc_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 learner_id uuid not null references public.kc_learners(id) on delete cascade,
 school_date date not null,
 kind text not null check(kind in ('absence','correction')),
 status text not null,
 body text not null,
 is_read boolean not null default false,
 created_at timestamptz not null default now()
);
create index if not exists kc_notifications_user_idx on public.kc_notifications(user_id,created_at desc);
create table if not exists public.kc_announcements (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 2 and 120),
 body text not null check(length(trim(body)) between 2 and 4000),
 grade integer check(grade between 1 and 12), -- null = all classes
 priority text not null default 'Normal' check(priority in ('Normal','Important','Urgent')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.kc_messages (
 id uuid primary key default gen_random_uuid(),
 guardian_id uuid not null references public.kc_parent_profiles(user_id),
 sender_id uuid not null references auth.users(id),
 body text not null check(length(trim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create index if not exists kc_messages_guardian_idx on public.kc_messages(guardian_id,created_at);

-- Hardened helpers deliberately in an unexposed schema. Avoid recursion in RLS policies.
create schema if not exists kc_private;
revoke all on schema kc_private from public;
grant usage on schema kc_private to authenticated;
create or replace function kc_private.active_staff(p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.kc_portal_staff s where s.user_id=p_user and s.is_active);
$$;
create or replace function kc_private.is_admin(p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.kc_portal_staff s where s.user_id=p_user and s.is_active and s.role='Admin');
$$;
create or replace function kc_private.can_class(p_class uuid, p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
 select kc_private.is_admin(p_user) or exists(select 1 from public.kc_staff_classes sc
 join public.kc_portal_staff s on s.user_id=sc.user_id
 where sc.user_id=p_user and sc.class_id=p_class and s.is_active and s.role='Teacher');
$$;
create or replace function kc_private.is_linked(p_learner uuid, p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.kc_guardian_links gl where gl.user_id=p_user and gl.learner_id=p_learner);
$$;
create or replace function kc_private.can_talk_to(p_guardian uuid, p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
 select kc_private.is_admin(p_user) or exists(
 select 1 from public.kc_guardian_links gl
 join public.kc_learners l on l.id=gl.learner_id
 where gl.user_id=p_guardian and kc_private.can_class(l.class_id,p_user));
$$;
revoke all on all functions in schema kc_private from public;
grant execute on all functions in schema kc_private to authenticated;

-- RLS on EVERY public table; explicit privileges are separate from RLS.
do $$ declare t text; begin foreach t in array array[
 'kc_classes','kc_learners','kc_parent_profiles','kc_guardian_links','kc_staff_classes',
 'kc_marks','kc_attendance','kc_notifications','kc_announcements','kc_messages'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 end loop; end $$;
grant insert,update on public.kc_parent_profiles to authenticated;
grant insert,update,delete on public.kc_classes,public.kc_learners,public.kc_guardian_links,public.kc_staff_classes to authenticated;
grant insert,update on public.kc_marks to authenticated;
grant update(is_read) on public.kc_notifications to authenticated;
grant insert on public.kc_announcements,public.kc_messages to authenticated;
-- Attendance is written exclusively through an atomic validated RPC, not table writes.

create policy "kc classes staff read" on public.kc_classes for select to authenticated using (kc_private.can_class(id));
create policy "kc classes guardian read" on public.kc_classes for select to authenticated using(exists(select 1 from public.kc_learners l where l.class_id=kc_classes.id and kc_private.is_linked(l.id)));
create policy "kc classes admin insert" on public.kc_classes for insert to authenticated with check(kc_private.is_admin());
create policy "kc classes admin update" on public.kc_classes for update to authenticated using(kc_private.is_admin()) with check(kc_private.is_admin());
create policy "kc learners staff read" on public.kc_learners for select to authenticated using(kc_private.can_class(class_id));
create policy "kc learners guardian read" on public.kc_learners for select to authenticated using(kc_private.is_linked(id));
create policy "kc learners admin insert" on public.kc_learners for insert to authenticated with check(kc_private.is_admin());
create policy "kc learners admin update" on public.kc_learners for update to authenticated using(kc_private.is_admin()) with check(kc_private.is_admin());
create policy "kc parent self read" on public.kc_parent_profiles for select to authenticated using(user_id=(select auth.uid()));
create policy "kc parent staff read" on public.kc_parent_profiles for select to authenticated using(kc_private.is_admin() or exists(select 1 from public.kc_guardian_links gl join public.kc_learners l on l.id=gl.learner_id where gl.user_id=kc_parent_profiles.user_id and kc_private.can_class(l.class_id)));
create policy "kc parent self insert" on public.kc_parent_profiles for insert to authenticated with check(user_id=(select auth.uid()) and lower(email)=lower((auth.jwt()->>'email')) and not kc_private.active_staff());
create policy "kc parent self update" on public.kc_parent_profiles for update to authenticated using(user_id=(select auth.uid()) and not kc_private.active_staff()) with check(user_id=(select auth.uid()) and lower(email)=lower((auth.jwt()->>'email')) and not kc_private.active_staff());
create policy "kc guardian staff read" on public.kc_guardian_links for select to authenticated using(kc_private.is_admin() or exists(select 1 from public.kc_learners l where l.id=learner_id and kc_private.can_class(l.class_id)));
create policy "kc guardian self read" on public.kc_guardian_links for select to authenticated using(user_id=(select auth.uid()));
create policy "kc guardian admin insert" on public.kc_guardian_links for insert to authenticated with check(kc_private.is_admin() and verified_by=(select auth.uid()));
create policy "kc guardian admin delete" on public.kc_guardian_links for delete to authenticated using(kc_private.is_admin());
create policy "kc class assignment staff read" on public.kc_staff_classes for select to authenticated using(kc_private.is_admin() or user_id=(select auth.uid()));
create policy "kc class assignment admin insert" on public.kc_staff_classes for insert to authenticated with check(kc_private.is_admin());
create policy "kc class assignment admin delete" on public.kc_staff_classes for delete to authenticated using(kc_private.is_admin());
create policy "kc marks permitted read" on public.kc_marks for select to authenticated using(kc_private.is_linked(learner_id) or exists(select 1 from public.kc_learners l where l.id=learner_id and kc_private.can_class(l.class_id)));
create policy "kc marks staff insert" on public.kc_marks for insert to authenticated with check(updated_by=(select auth.uid()) and exists(select 1 from public.kc_learners l where l.id=learner_id and kc_private.can_class(l.class_id)));
create policy "kc marks staff update" on public.kc_marks for update to authenticated using(exists(select 1 from public.kc_learners l where l.id=learner_id and kc_private.can_class(l.class_id))) with check(updated_by=(select auth.uid()) and exists(select 1 from public.kc_learners l where l.id=learner_id and kc_private.can_class(l.class_id)));
create policy "kc attendance permitted read" on public.kc_attendance for select to authenticated using(kc_private.is_linked(learner_id) or exists(select 1 from public.kc_learners l where l.id=learner_id and kc_private.can_class(l.class_id)));
create policy "kc notifications guardian read" on public.kc_notifications for select to authenticated using(user_id=(select auth.uid()));
create policy "kc notifications guardian update" on public.kc_notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "kc news permitted read" on public.kc_announcements for select to authenticated using(
 kc_private.active_staff() or exists(select 1 from public.kc_guardian_links gl join public.kc_learners l on l.id=gl.learner_id join public.kc_classes c on c.id=l.class_id
 where gl.user_id=(select auth.uid()) and (kc_announcements.grade is null or kc_announcements.grade=c.grade)));
create policy "kc news staff publish" on public.kc_announcements for insert to authenticated with check(kc_private.active_staff() and created_by=(select auth.uid()));
create policy "kc messages guardian read" on public.kc_messages for select to authenticated using(guardian_id=(select auth.uid()) or kc_private.can_talk_to(guardian_id));
create policy "kc messages verified write" on public.kc_messages for insert to authenticated with check(
 sender_id=(select auth.uid()) and (
  (guardian_id=(select auth.uid()) and exists(select 1 from public.kc_guardian_links where user_id=guardian_id))
  or kc_private.can_talk_to(guardian_id)));

-- One atomic roll call submission; validation + persistent rows + notifications commit together.
-- Strictly school staff; teachers only for assigned classes, admin all classes.
create or replace function public.kc_submit_rollcall(p_class_id uuid,p_school_date date,p_statuses jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_required integer; v_supplied integer; v_row record; v_old text;
 v_absences integer := 0; v_corrections integer := 0; v_saved integer := 0; v_guard record;
begin
 if v_actor is null or not kc_private.can_class(p_class_id,v_actor) then raise exception 'Not permitted to submit this class register'; end if;
 if p_school_date is null or p_school_date > (now() at time zone 'Africa/Johannesburg')::date or p_school_date < (now() at time zone 'Africa/Johannesburg')::date-31 then raise exception 'School date must be within the last 31 days'; end if;
 if p_statuses is null or jsonb_typeof(p_statuses) <> 'object' then raise exception 'Invalid register format'; end if;
 select count(*) into v_required from public.kc_learners where class_id=p_class_id and active;
 select count(*) into v_supplied from jsonb_each(p_statuses);
 if v_required=0 or v_supplied<>v_required then raise exception 'Every active learner must be marked exactly once'; end if;
 -- Lock roster to prevent competing submissions during validation/updates.
 perform 1 from public.kc_learners where class_id=p_class_id and active for update;
 for v_row in select id, full_name from public.kc_learners where class_id=p_class_id and active loop
  if not (p_statuses ? (v_row.id::text)) or p_statuses->>v_row.id::text not in ('Present','Absent','Late','Excused') then
    raise exception 'Invalid or missing status for a learner'; end if;
  select status into v_old from public.kc_attendance where learner_id=v_row.id and school_date=p_school_date for update;
  if v_old is distinct from p_statuses->>v_row.id::text then
   insert into public.kc_attendance(learner_id,school_date,status,recorded_by)
   values(v_row.id,p_school_date,p_statuses->>v_row.id::text,v_actor)
   on conflict(learner_id,school_date) do update set status=excluded.status,recorded_by=excluded.recorded_by,updated_at=now();
   v_saved := v_saved+1;
   if p_statuses->>v_row.id::text='Absent' then
    for v_guard in select user_id from public.kc_guardian_links where learner_id=v_row.id loop
     insert into public.kc_notifications(user_id,learner_id,school_date,kind,status,body)
     values(v_guard.user_id,v_row.id,p_school_date,'absence','Absent',
       v_row.full_name || ' was recorded absent at morning roll call on ' || p_school_date::text || '. If unexpected, please contact the school.');
     v_absences := v_absences+1;
    end loop;
   elsif v_old='Absent' then
    for v_guard in select user_id from public.kc_guardian_links where learner_id=v_row.id loop
     insert into public.kc_notifications(user_id,learner_id,school_date,kind,status,body)
     values(v_guard.user_id,v_row.id,p_school_date,'correction',p_statuses->>v_row.id::text,
       'Attendance correction for '||v_row.full_name||' on '||p_school_date::text||': updated to '|| (p_statuses->>v_row.id::text)||'.');
     v_corrections := v_corrections+1;
    end loop;
   end if;
  end if;
 end loop;
 return jsonb_build_object('saved',v_saved,'created',v_absences,'corrected',v_corrections);
end; $$;
revoke execute on function public.kc_submit_rollcall(uuid,date,jsonb) from public,anon;
grant execute on function public.kc_submit_rollcall(uuid,date,jsonb) to authenticated;
-- IMPORTANT: the database creates IN-APP alerts. Device push requires an additional FCM/APNs delivery worker.

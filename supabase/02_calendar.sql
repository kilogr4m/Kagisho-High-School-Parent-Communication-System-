-- Optional school calendar, run AFTER 01_kagisho_shared_schema.sql
create table if not exists public.kc_events (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 2 and 120),
 description text not null default '',
 school_date date not null,
 grade integer check(grade between 1 and 12), -- null=whole school
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists kc_events_date_idx on public.kc_events(school_date);
alter table public.kc_events enable row level security;
revoke all on public.kc_events from anon,authenticated;
grant select,insert on public.kc_events to authenticated;
create policy "kc events staff read" on public.kc_events for select to authenticated using(kc_private.active_staff());
create policy "kc events parent read" on public.kc_events for select to authenticated using(exists(
  select 1 from public.kc_guardian_links gl join public.kc_learners l on l.id=gl.learner_id
  join public.kc_classes c on c.id=l.class_id
  where gl.user_id=(select auth.uid()) and (kc_events.grade is null or kc_events.grade=c.grade)
));
create policy "kc events staff insert" on public.kc_events for insert to authenticated with check(kc_private.active_staff() and created_by=(select auth.uid()));

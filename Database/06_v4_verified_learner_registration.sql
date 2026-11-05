-- Kagisho Connect V4: targeted registration repair, 05 November 2026.
-- Requires the EXISTING kc_* schema and the V6 guardian-request migration (04_parent_experience.sql).
-- REVIEW and back up the Supabase project before running in SQL Editor.
-- Additive only: does not delete records or update existing guardian requests.
-- The administrator must independently verify a parent's identity and guardianship.

-- A successful call creates BOTH the learner and their verified DOB in ONE transaction.
-- Security invoker means the caller's Supabase JWT and existing RLS apply.
create or replace function public.kc_register_learner_verified(
    p_name text,
    p_class_id uuid,
    p_admission_number text,
    p_birth_date date
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_learner_id uuid;
    v_class_grade integer;
begin
    if not kc_private.is_admin() then
        raise exception 'Only a school administrator can register a learner';
    end if;
    if p_name is null or length(trim(p_name)) not between 2 and 100 then
        raise exception 'Enter the learner full name';
    end if;
    if p_admission_number is null or length(trim(p_admission_number)) not between 4 and 32 then
        raise exception 'Enter a unique admission number (4 to 32 characters)';
    end if;
    if p_birth_date is null or p_birth_date < date '1990-01-01' or p_birth_date > current_date then
        raise exception 'Enter the verified date of birth';
    end if;
    select c.grade into v_class_grade
      from public.kc_classes c
      where c.id = p_class_id;
    if v_class_grade is null or v_class_grade not between 8 and 12 then
        raise exception 'Select an existing Grade 8 to 12 class';
    end if;
    -- Unique admission numbers are enforced by the existing V5 index.
    if exists (
        select 1 from public.kc_learners l
        where lower(trim(l.admission_number)) = lower(trim(p_admission_number))
    ) then
        raise exception 'This admission number is already registered';
    end if;
    -- Prevent a second active registration for the same verified learner,
    -- while preserving all existing UUIDs and unrelated records.
    if exists (
        select 1
          from public.kc_learners l
          join public.kc_learner_birthdates b on b.learner_id = l.id
         where l.active = true
           and lower(regexp_replace(trim(l.full_name), '\s+', ' ', 'g')) =
               lower(regexp_replace(trim(p_name), '\s+', ' ', 'g'))
           and b.birth_date = p_birth_date
    ) then
        raise exception 'A learner with this name and verified birth date already exists';
    end if;
    insert into public.kc_learners(full_name, class_id, admission_number, active)
       values(trim(p_name), p_class_id, trim(p_admission_number), true)
       returning id into v_learner_id;
    insert into public.kc_learner_birthdates(learner_id, birth_date)
       values(v_learner_id, p_birth_date);
    return v_learner_id;
end;
$$;

revoke all on function public.kc_register_learner_verified(text,uuid,text,date) from public;
revoke all on function public.kc_register_learner_verified(text,uuid,text,date) from anon;
grant execute on function public.kc_register_learner_verified(text,uuid,text,date) to authenticated;

-- A SELECT of private birth dates is never granted to parents.
-- Admin-only DOB RLS is provided by the existing 04_parent_experience.sql.

-- Phase 1 (staging): leave policy resolver + active binding summary
-- Scope:
-- 1) add binding summary function
-- 2) refine MISSING_COUNTRY_DATA message detail
-- 3) keep upsert as upsert + summary report only
-- 4) DO NOT batch-rewrite historical holiday_calendar_days data

drop function if exists public.get_leave_policy_binding_summary(uuid, uuid, text);
create function public.get_leave_policy_binding_summary(
  p_org_id uuid,
  p_company_id uuid,
  p_country_code text default null
)
returns table (
  resolved_env text,
  profile_id uuid,
  profile_country_code text,
  allow_cross_country_holiday_merge boolean,
  active_source_count int,
  active_day_count int,
  active_warning_count int,
  foreign_source_count int,
  foreign_day_count int,
  foreign_warning_count int,
  mismatch_day_source_country_count int,
  mismatch_warning_profile_country_count int,
  has_active_country_data boolean,
  has_foreign_data boolean,
  binding_status text,
  message text
)
language sql
stable
security invoker
set search_path = public
as $$
  -- NOTE (Phase 1 semantics):
  -- active_* counts are resolver-visible counts.
  -- When allow_cross_country_holiday_merge=true, these counts are not equivalent
  -- to final assignment-engine applicable scope (assignment engine is out of Phase 1).
  with ctx as (
    select *
    from public.leave_policy_resolve_country_context(p_org_id, p_company_id, p_country_code)
  ),
  src as (
    select s.*
    from public.holiday_calendar_sources s
    join ctx on true
    where s.org_id = p_org_id
      and s.company_id = p_company_id
      and (ctx.resolved_env is null or s.environment_type = ctx.resolved_env)
  ),
  day as (
    select d.*
    from public.holiday_calendar_days d
    join ctx on true
    where d.org_id = p_org_id
      and d.company_id = p_company_id
      and (ctx.resolved_env is null or d.environment_type = ctx.resolved_env)
  ),
  warn as (
    select w.*
    from public.leave_compliance_warnings w
    join ctx on true
    where w.org_id = p_org_id
      and w.company_id = p_company_id
      and (ctx.resolved_env is null or w.environment_type = ctx.resolved_env)
  ),
  agg as (
    select
      (select resolved_env from ctx) as resolved_env,
      (select profile_id from ctx) as profile_id,
      (select resolved_country from ctx) as profile_country_code,
      coalesce((select allow_cross_country_holiday_merge from ctx), false) as allow_merge,

      (select count(*)::int from src s, ctx c
        where c.allow_cross_country_holiday_merge = true or s.country_code = c.resolved_country) as active_source_count,
      (select count(*)::int from day d, ctx c
        where c.allow_cross_country_holiday_merge = true or d.country_code = c.resolved_country) as active_day_count,
      (select count(*)::int from warn w, ctx c
        where c.allow_cross_country_holiday_merge = true or w.country_code = c.resolved_country) as active_warning_count,

      (select count(*)::int from src s, ctx c where s.country_code <> c.resolved_country) as foreign_source_count,
      (select count(*)::int from day d, ctx c where d.country_code <> c.resolved_country) as foreign_day_count,
      (select count(*)::int from warn w, ctx c where w.country_code <> c.resolved_country) as foreign_warning_count,

      -- true mismatch check #1: holiday day country differs from linked source country.
      (select count(*)::int
       from public.holiday_calendar_days d
       join public.holiday_calendar_sources s on s.id = d.source_id
       where d.org_id = p_org_id
         and d.company_id = p_company_id
         and d.country_code is distinct from s.country_code) as mismatch_day_source_country_count,

      -- true mismatch check #2:
      -- Phase 1 assumes warning binds to its current policy_profile_id country.
      -- If profile versioning is introduced later, this should be scoped to active/current version model.
      (select count(*)::int
       from public.leave_compliance_warnings w
       join public.leave_policy_profiles p on p.id = w.policy_profile_id
       where w.org_id = p_org_id
         and w.company_id = p_company_id
         and w.country_code is distinct from p.country_code) as mismatch_warning_profile_country_count
  )
  select
    a.resolved_env,
    a.profile_id,
    a.profile_country_code,
    a.allow_merge as allow_cross_country_holiday_merge,
    a.active_source_count,
    a.active_day_count,
    a.active_warning_count,
    a.foreign_source_count,
    a.foreign_day_count,
    a.foreign_warning_count,
    a.mismatch_day_source_country_count,
    a.mismatch_warning_profile_country_count,
    ((a.active_source_count > 0) and (a.active_day_count > 0)) as has_active_country_data,
    ((a.foreign_source_count + a.foreign_day_count + a.foreign_warning_count) > 0) as has_foreign_data,
    case
      when (a.mismatch_day_source_country_count + a.mismatch_warning_profile_country_count) > 0
        then 'MISMATCH'
      when (a.active_source_count = 0 or a.active_day_count = 0)
        then 'MISSING_COUNTRY_DATA'
      when (a.allow_merge = false)
           and ((a.foreign_source_count + a.foreign_day_count + a.foreign_warning_count) > 0)
        then 'CROSS_COUNTRY_DISABLED_HAS_FOREIGN_DATA'
      else 'ALIGNED'
    end as binding_status,
    case
      when (a.mismatch_day_source_country_count + a.mismatch_warning_profile_country_count) > 0
        then 'Detected country mismatch in linked records'
      when (a.active_source_count = 0 and a.active_day_count = 0)
        then 'Missing holiday source and holiday days for resolved country'
      when (a.active_source_count = 0 and a.active_day_count > 0)
        then 'Missing holiday source for resolved country'
      when (a.active_source_count > 0 and a.active_day_count = 0)
        then 'Missing holiday days for resolved country'
      when (a.allow_merge = false)
           and ((a.foreign_source_count + a.foreign_day_count + a.foreign_warning_count) > 0)
        then 'Primary policy country is active; foreign-country data exists but is not active while cross-country merge is disabled'
      else 'Active resolver is aligned'
    end as message
  from agg a
$$;

create or replace function public.upsert_leave_policy_profile(
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_id uuid := coalesce(nullif(p_payload ->> 'id', '')::uuid, gen_random_uuid());
  v_org_id uuid := nullif(p_payload ->> 'org_id', '')::uuid;
  v_company_id uuid := nullif(p_payload ->> 'company_id', '')::uuid;
  v_environment_type text := coalesce(
    nullif(p_payload ->> 'environment_type', ''),
    public.leave_policy_resolve_environment(v_org_id, v_company_id),
    'production'
  );
  v_is_demo boolean := coalesce((p_payload ->> 'is_demo')::boolean, v_environment_type = 'demo');
  v_country_code text := upper(nullif(trim(coalesce(p_payload ->> 'country_code', '')), ''));
  v_policy_name text := nullif(trim(coalesce(p_payload ->> 'policy_name', '')), '');
  v_effective_from date := nullif(p_payload ->> 'effective_from', '')::date;
  v_effective_to date := nullif(p_payload ->> 'effective_to', '')::date;
  v_leave_year_mode text := nullif(trim(coalesce(p_payload ->> 'leave_year_mode', '')), '');
  v_holiday_mode text := nullif(trim(coalesce(p_payload ->> 'holiday_mode', '')), '');
  v_allow_merge boolean := coalesce((p_payload ->> 'allow_cross_country_holiday_merge')::boolean, false);
  v_payroll_policy_mode text := nullif(trim(coalesce(p_payload ->> 'payroll_policy_mode', '')), '');
  v_warning_enabled boolean := coalesce((p_payload ->> 'compliance_warning_enabled')::boolean, true);
  v_notes text := nullif(trim(coalesce(p_payload ->> 'notes', '')), '');
  v_actor_user_id uuid := auth.uid();
  v_row public.leave_policy_profiles%rowtype;
  v_summary record;
begin
  if v_org_id is null or v_company_id is null then
    raise exception 'ORG_COMPANY_REQUIRED';
  end if;
  if v_country_code is null or v_policy_name is null or v_effective_from is null then
    raise exception 'PROFILE_REQUIRED_FIELDS_MISSING';
  end if;

  insert into public.leave_policy_profiles (
    id,
    org_id,
    company_id,
    environment_type,
    is_demo,
    country_code,
    policy_name,
    effective_from,
    effective_to,
    leave_year_mode,
    holiday_mode,
    allow_cross_country_holiday_merge,
    payroll_policy_mode,
    compliance_warning_enabled,
    notes,
    created_at,
    updated_at,
    created_by,
    updated_by
  ) values (
    v_id,
    v_org_id,
    v_company_id,
    v_environment_type,
    v_is_demo,
    v_country_code,
    v_policy_name,
    v_effective_from,
    v_effective_to,
    v_leave_year_mode,
    v_holiday_mode,
    v_allow_merge,
    v_payroll_policy_mode,
    v_warning_enabled,
    v_notes,
    now(),
    now(),
    v_actor_user_id,
    v_actor_user_id
  )
  on conflict (org_id, company_id, country_code, policy_name, effective_from, environment_type)
  do update set
    effective_to = excluded.effective_to,
    leave_year_mode = excluded.leave_year_mode,
    holiday_mode = excluded.holiday_mode,
    allow_cross_country_holiday_merge = excluded.allow_cross_country_holiday_merge,
    payroll_policy_mode = excluded.payroll_policy_mode,
    compliance_warning_enabled = excluded.compliance_warning_enabled,
    notes = excluded.notes,
    is_demo = excluded.is_demo,
    updated_at = now(),
    updated_by = excluded.updated_by
  returning *
    into v_row;

  -- Phase 1 rule:
  -- upsert only returns binding summary for UI/ops visibility.
  -- No data repair logic is executed in this function.
  select *
    into v_summary
  from public.get_leave_policy_binding_summary(v_org_id, v_company_id, v_country_code)
  limit 1;

  return jsonb_build_object(
    'policy_profile_id', v_row.id,
    'org_id', v_row.org_id,
    'company_id', v_row.company_id,
    'environment_type', v_row.environment_type,
    'country_code', v_row.country_code,
    'policy_name', v_row.policy_name,
    'effective_from', v_row.effective_from,
    'effective_to', v_row.effective_to,
    'updated_at', v_row.updated_at,
    'binding_summary', jsonb_build_object(
      'resolved_env', v_summary.resolved_env,
      'profile_id', v_summary.profile_id,
      'profile_country_code', v_summary.profile_country_code,
      'allow_cross_country_holiday_merge', v_summary.allow_cross_country_holiday_merge,
      'active_source_count', v_summary.active_source_count,
      'active_day_count', v_summary.active_day_count,
      'active_warning_count', v_summary.active_warning_count,
      'foreign_source_count', v_summary.foreign_source_count,
      'foreign_day_count', v_summary.foreign_day_count,
      'foreign_warning_count', v_summary.foreign_warning_count,
      'mismatch_day_source_country_count', v_summary.mismatch_day_source_country_count,
      'mismatch_warning_profile_country_count', v_summary.mismatch_warning_profile_country_count,
      'has_active_country_data', v_summary.has_active_country_data,
      'has_foreign_data', v_summary.has_foreign_data,
      'binding_status', v_summary.binding_status,
      'message', v_summary.message
    )
  );
end;
$$;

grant execute on function public.get_leave_policy_binding_summary(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.upsert_leave_policy_profile(jsonb) to authenticated, service_role;

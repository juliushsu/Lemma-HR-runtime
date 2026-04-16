-- Leave policy country binding consistency + employee/org-chart adapter contracts (staging)

create or replace function public.leave_policy_resolve_country_context(
  p_org_id uuid,
  p_company_id uuid,
  p_country_code text default null
)
returns table (
  resolved_env text,
  resolved_country text,
  allow_cross_country_holiday_merge boolean,
  profile_id uuid
)
language sql
stable
security invoker
set search_path = public
as $$
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
  ),
  candidate as (
    select p.*
    from public.leave_policy_profiles p
    where p.org_id = p_org_id
      and p.company_id = p_company_id
      and ((select resolved_env from env) is null or p.environment_type = (select resolved_env from env))
    order by
      case
        when nullif(upper(trim(coalesce(p_country_code, ''))), '') is not null
             and p.country_code = nullif(upper(trim(coalesce(p_country_code, ''))), '') then 0
        else 1
      end,
      case when p.effective_from <= current_date and (p.effective_to is null or p.effective_to >= current_date) then 0 else 1 end,
      p.effective_from desc,
      p.updated_at desc
    limit 1
  )
  select
    coalesce((select resolved_env from env), (select environment_type from candidate)) as resolved_env,
    coalesce(nullif(upper(trim(coalesce(p_country_code, ''))), ''), (select country_code from candidate)) as resolved_country,
    coalesce((select allow_cross_country_holiday_merge from candidate), false) as allow_cross_country_holiday_merge,
    (select id from candidate) as profile_id
$$;

-- country-aware holiday sources

drop function if exists public.list_holiday_calendar_sources(uuid, uuid, text);
create function public.list_holiday_calendar_sources(
  p_org_id uuid,
  p_company_id uuid,
  p_country_code text
)
returns table (
  source_id uuid,
  country_code text,
  source_type text,
  source_name text,
  source_ref text,
  is_enabled boolean,
  last_synced_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with req as (
    select nullif(upper(trim(coalesce(p_country_code, ''))), '') as requested_country
  ),
  ctx as (
    select * from public.leave_policy_resolve_country_context(
      p_org_id,
      p_company_id,
      (select requested_country from req)
    )
  )
  select
    s.id as source_id,
    s.country_code,
    s.source_type,
    s.source_name,
    s.source_ref,
    s.is_enabled,
    s.last_synced_at,
    s.created_at,
    s.updated_at
  from public.holiday_calendar_sources s
  cross join ctx
  cross join req
  where s.org_id = p_org_id
    and s.company_id = p_company_id
    and (ctx.resolved_env is null or s.environment_type = ctx.resolved_env)
    and (
      (req.requested_country is not null and s.country_code = req.requested_country)
      or (
        req.requested_country is null
        and (
          ctx.allow_cross_country_holiday_merge = true
          or ctx.resolved_country is null
          or s.country_code = ctx.resolved_country
        )
      )
    )
  order by s.country_code asc, s.source_type asc, s.source_name asc
$$;

drop function if exists public.list_holiday_calendar_sources(uuid, uuid);
create function public.list_holiday_calendar_sources(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  source_id uuid,
  country_code text,
  source_type text,
  source_name text,
  source_ref text,
  is_enabled boolean,
  last_synced_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select *
  from public.list_holiday_calendar_sources(p_org_id, p_company_id, null::text)
$$;

-- country-aware holiday days

drop function if exists public.list_holiday_calendar_days(uuid, uuid, text, date, date);
create function public.list_holiday_calendar_days(
  p_org_id uuid,
  p_company_id uuid,
  p_country_code text,
  p_from_date date,
  p_to_date date
)
returns table (
  holiday_day_id uuid,
  country_code text,
  holiday_date date,
  holiday_name text,
  holiday_category text,
  is_paid_day_off boolean,
  source_id uuid,
  source_name text,
  source_type text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with req as (
    select nullif(upper(trim(coalesce(p_country_code, ''))), '') as requested_country
  ),
  ctx as (
    select * from public.leave_policy_resolve_country_context(
      p_org_id,
      p_company_id,
      (select requested_country from req)
    )
  )
  select
    d.id as holiday_day_id,
    d.country_code,
    d.holiday_date,
    d.holiday_name,
    d.holiday_category,
    d.is_paid_day_off,
    d.source_id,
    s.source_name,
    s.source_type,
    d.created_at,
    d.updated_at
  from public.holiday_calendar_days d
  left join public.holiday_calendar_sources s on s.id = d.source_id
  cross join ctx
  cross join req
  where d.org_id = p_org_id
    and d.company_id = p_company_id
    and (ctx.resolved_env is null or d.environment_type = ctx.resolved_env)
    and (
      (req.requested_country is not null and d.country_code = req.requested_country)
      or (
        req.requested_country is null
        and (
          ctx.allow_cross_country_holiday_merge = true
          or ctx.resolved_country is null
          or d.country_code = ctx.resolved_country
        )
      )
    )
    and (p_from_date is null or d.holiday_date >= p_from_date)
    and (p_to_date is null or d.holiday_date <= p_to_date)
  order by d.holiday_date asc, d.holiday_name asc
$$;

drop function if exists public.list_holiday_calendar_days(uuid, uuid, date, date);
create function public.list_holiday_calendar_days(
  p_org_id uuid,
  p_company_id uuid,
  p_from_date date default null,
  p_to_date date default null
)
returns table (
  holiday_day_id uuid,
  country_code text,
  holiday_date date,
  holiday_name text,
  holiday_category text,
  is_paid_day_off boolean,
  source_id uuid,
  source_name text,
  source_type text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select *
  from public.list_holiday_calendar_days(p_org_id, p_company_id, null::text, p_from_date, p_to_date)
$$;

-- country-aware compliance warnings

drop function if exists public.list_leave_compliance_warnings(uuid, uuid, text);
create function public.list_leave_compliance_warnings(
  p_org_id uuid,
  p_company_id uuid,
  p_country_code text
)
returns table (
  warning_id uuid,
  policy_profile_id uuid,
  warning_type text,
  severity text,
  title text,
  message text,
  country_code text,
  related_rule_ref text,
  is_resolved boolean,
  resolution_note text,
  resolved_at timestamptz,
  resolved_by uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with req as (
    select nullif(upper(trim(coalesce(p_country_code, ''))), '') as requested_country
  ),
  ctx as (
    select * from public.leave_policy_resolve_country_context(
      p_org_id,
      p_company_id,
      (select requested_country from req)
    )
  )
  select
    w.id as warning_id,
    w.policy_profile_id,
    w.warning_type,
    w.severity,
    w.title,
    w.message,
    w.country_code,
    w.related_rule_ref,
    w.is_resolved,
    w.resolution_note,
    w.resolved_at,
    w.resolved_by,
    w.created_at,
    w.updated_at
  from public.leave_compliance_warnings w
  cross join ctx
  cross join req
  where w.org_id = p_org_id
    and w.company_id = p_company_id
    and (ctx.resolved_env is null or w.environment_type = ctx.resolved_env)
    and (
      (req.requested_country is not null and w.country_code = req.requested_country)
      or (
        req.requested_country is null
        and (
          ctx.allow_cross_country_holiday_merge = true
          or ctx.resolved_country is null
          or w.country_code = ctx.resolved_country
        )
      )
    )
  order by w.is_resolved asc, w.severity desc, w.created_at desc
$$;

drop function if exists public.list_leave_compliance_warnings(uuid, uuid);
create function public.list_leave_compliance_warnings(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  warning_id uuid,
  policy_profile_id uuid,
  warning_type text,
  severity text,
  title text,
  message text,
  country_code text,
  related_rule_ref text,
  is_resolved boolean,
  resolution_note text,
  resolved_at timestamptz,
  resolved_by uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select *
  from public.list_leave_compliance_warnings(p_org_id, p_company_id, null::text)
$$;

-- Employee detail / org relation adapter-ready contracts

drop function if exists public.get_employee_detail(text);
create function public.get_employee_detail(
  p_employee_id text
)
returns table (
  employee_id uuid,
  employee_code text,
  full_name_local text,
  full_name_latin text,
  preferred_locale text,
  timezone text,
  employment_type text,
  employment_status text,
  department_name text,
  position_title text,
  manager_employee_id uuid,
  manager_name text,
  direct_reports_count int,
  hire_date date,
  avatar_url text
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_ref text := nullif(trim(coalesce(p_employee_id, '')), '');
  v_ref_uuid uuid;
begin
  if v_ref is null then
    return;
  end if;

  begin
    v_ref_uuid := v_ref::uuid;
  exception
    when others then
      v_ref_uuid := null;
  end;

  return query
  with target as (
    select e.*
    from public.employees e
    where (v_ref_uuid is not null and e.id = v_ref_uuid)
       or upper(e.employee_code) = upper(v_ref)
    order by case when v_ref_uuid is not null and e.id = v_ref_uuid then 0 else 1 end
    limit 1
  ),
  report_counts as (
    select
      r.manager_employee_id,
      count(*)::int as direct_reports_count
    from public.employees r
    join target t
      on t.id = r.manager_employee_id
     and t.org_id = r.org_id
     and t.company_id = r.company_id
     and t.environment_type = r.environment_type
    group by r.manager_employee_id
  )
  select
    t.id as employee_id,
    t.employee_code,
    t.full_name_local,
    t.full_name_latin,
    t.preferred_locale,
    t.timezone,
    t.employment_type,
    t.employment_status,
    d.department_name,
    p.position_name as position_title,
    t.manager_employee_id,
    coalesce(m.full_name_local, m.display_name, m.full_name_latin, m.employee_code) as manager_name,
    coalesce(rc.direct_reports_count, 0)::int as direct_reports_count,
    t.hire_date,
    null::text as avatar_url
  from target t
  left join public.departments d
    on d.id = t.department_id
   and d.org_id = t.org_id
   and d.company_id = t.company_id
   and d.environment_type = t.environment_type
  left join public.positions p
    on p.id = t.position_id
   and p.org_id = t.org_id
   and p.company_id = t.company_id
   and p.environment_type = t.environment_type
  left join public.employees m
    on m.id = t.manager_employee_id
   and m.org_id = t.org_id
   and m.company_id = t.company_id
   and m.environment_type = t.environment_type
  left join report_counts rc
    on rc.manager_employee_id = t.id;
end;
$$;

drop function if exists public.list_employee_direct_reports(text);
create function public.list_employee_direct_reports(
  p_employee_id text
)
returns table (
  report_employee_id uuid,
  employee_code text,
  full_name_local text,
  full_name_latin text,
  display_name text,
  employment_status text,
  department_name text,
  position_title text,
  hire_date date
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_ref text := nullif(trim(coalesce(p_employee_id, '')), '');
  v_ref_uuid uuid;
begin
  if v_ref is null then
    return;
  end if;

  begin
    v_ref_uuid := v_ref::uuid;
  exception
    when others then
      v_ref_uuid := null;
  end;

  return query
  with target as (
    select e.*
    from public.employees e
    where (v_ref_uuid is not null and e.id = v_ref_uuid)
       or upper(e.employee_code) = upper(v_ref)
    order by case when v_ref_uuid is not null and e.id = v_ref_uuid then 0 else 1 end
    limit 1
  )
  select
    r.id as report_employee_id,
    r.employee_code,
    r.full_name_local,
    r.full_name_latin,
    r.display_name,
    r.employment_status,
    d.department_name,
    p.position_name as position_title,
    r.hire_date
  from public.employees r
  join target t
    on r.manager_employee_id = t.id
   and r.org_id = t.org_id
   and r.company_id = t.company_id
   and r.environment_type = t.environment_type
  left join public.departments d
    on d.id = r.department_id
   and d.org_id = r.org_id
   and d.company_id = r.company_id
   and d.environment_type = r.environment_type
  left join public.positions p
    on p.id = r.position_id
   and p.org_id = r.org_id
   and p.company_id = r.company_id
   and p.environment_type = r.environment_type
  order by r.employee_code asc;
end;
$$;

drop function if exists public.list_employee_org_relations(text);
create function public.list_employee_org_relations(
  p_employee_id text
)
returns table (
  employee_id uuid,
  org_id uuid,
  company_id uuid,
  branch_id uuid,
  environment_type text,
  department_id uuid,
  department_name text,
  position_id uuid,
  position_title text,
  manager_employee_id uuid,
  manager_name text,
  direct_reports_count int
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_ref text := nullif(trim(coalesce(p_employee_id, '')), '');
  v_ref_uuid uuid;
begin
  if v_ref is null then
    return;
  end if;

  begin
    v_ref_uuid := v_ref::uuid;
  exception
    when others then
      v_ref_uuid := null;
  end;

  return query
  with target as (
    select e.*
    from public.employees e
    where (v_ref_uuid is not null and e.id = v_ref_uuid)
       or upper(e.employee_code) = upper(v_ref)
    order by case when v_ref_uuid is not null and e.id = v_ref_uuid then 0 else 1 end
    limit 1
  ),
  report_counts as (
    select
      r.manager_employee_id,
      count(*)::int as direct_reports_count
    from public.employees r
    join target t
      on t.id = r.manager_employee_id
     and t.org_id = r.org_id
     and t.company_id = r.company_id
     and t.environment_type = r.environment_type
    group by r.manager_employee_id
  )
  select
    t.id as employee_id,
    t.org_id,
    t.company_id,
    t.branch_id,
    t.environment_type,
    t.department_id,
    d.department_name,
    t.position_id,
    p.position_name as position_title,
    t.manager_employee_id,
    coalesce(m.full_name_local, m.display_name, m.full_name_latin, m.employee_code) as manager_name,
    coalesce(rc.direct_reports_count, 0)::int as direct_reports_count
  from target t
  left join public.departments d
    on d.id = t.department_id
   and d.org_id = t.org_id
   and d.company_id = t.company_id
   and d.environment_type = t.environment_type
  left join public.positions p
    on p.id = t.position_id
   and p.org_id = t.org_id
   and p.company_id = t.company_id
   and p.environment_type = t.environment_type
  left join public.employees m
    on m.id = t.manager_employee_id
   and m.org_id = t.org_id
   and m.company_id = t.company_id
   and m.environment_type = t.environment_type
  left join report_counts rc
    on rc.manager_employee_id = t.id;
end;
$$;

grant execute on function public.leave_policy_resolve_country_context(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.list_holiday_calendar_sources(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_holiday_calendar_sources(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.list_holiday_calendar_days(uuid, uuid, date, date) to authenticated, service_role;
grant execute on function public.list_holiday_calendar_days(uuid, uuid, text, date, date) to authenticated, service_role;
grant execute on function public.list_leave_compliance_warnings(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_leave_compliance_warnings(uuid, uuid, text) to authenticated, service_role;

grant execute on function public.get_employee_detail(text) to authenticated, service_role;
grant execute on function public.list_employee_direct_reports(text) to authenticated, service_role;
grant execute on function public.list_employee_org_relations(text) to authenticated, service_role;

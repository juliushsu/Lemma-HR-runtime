-- HR employee profile minimal write layer + org chart resolver contract (staging)

create or replace function public.update_employee_profile(
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_ref text := nullif(trim(coalesce(
    p_payload ->> 'employee_id_or_code',
    p_payload ->> 'employee_id',
    p_payload ->> 'employee_code'
  )), '');
  v_ref_uuid uuid;

  v_org_id uuid := nullif(p_payload ->> 'org_id', '')::uuid;
  v_company_id uuid := nullif(p_payload ->> 'company_id', '')::uuid;
  v_environment_type text := nullif(trim(coalesce(p_payload ->> 'environment_type', '')), '');

  v_actor_user_id uuid := coalesce(auth.uid(), nullif(p_payload ->> 'actor_user_id', '')::uuid);

  v_employee public.employees%rowtype;
  v_candidate_count int;

  v_set_department boolean := (p_payload ? 'department_id') or (p_payload ? 'department_name');
  v_set_position boolean := (p_payload ? 'position_id') or (p_payload ? 'position_title');
  v_set_manager boolean := (p_payload ? 'manager_employee_id');
  v_set_employment_type boolean := (p_payload ? 'employment_type');
  v_set_employment_status boolean := (p_payload ? 'employment_status');
  v_set_preferred_locale boolean := (p_payload ? 'preferred_locale');
  v_set_timezone boolean := (p_payload ? 'timezone');
  v_set_hire_date boolean := (p_payload ? 'hire_date');

  v_department_id uuid;
  v_department_name text := nullif(trim(coalesce(p_payload ->> 'department_name', '')), '');
  v_department_match_count int;

  v_position_id uuid;
  v_position_title text := nullif(trim(coalesce(p_payload ->> 'position_title', '')), '');
  v_position_match_count int;

  v_manager_employee_id uuid;
  v_manager_ref text;

  v_employment_type text;
  v_employment_status text;
  v_preferred_locale text;
  v_timezone text;
  v_hire_date date;

  v_updated public.employees%rowtype;
  v_detail record;
begin
  if v_ref is null then
    raise exception 'EMPLOYEE_REF_REQUIRED';
  end if;

  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_REQUIRED';
  end if;

  if auth.uid() is not null and v_actor_user_id <> auth.uid() then
    raise exception 'ACTOR_USER_MISMATCH';
  end if;

  begin
    v_ref_uuid := v_ref::uuid;
  exception
    when others then
      v_ref_uuid := null;
  end;

  if v_ref_uuid is not null then
    select count(*)::int
      into v_candidate_count
    from public.employees e
    where e.id = v_ref_uuid
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type);

    if v_candidate_count = 0 then
      raise exception 'EMPLOYEE_NOT_FOUND';
    end if;

    select e.*
      into v_employee
    from public.employees e
    where e.id = v_ref_uuid
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type)
    limit 1;
  else
    select count(*)::int
      into v_candidate_count
    from public.employees e
    where upper(e.employee_code) = upper(v_ref)
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type);

    if v_candidate_count = 0 then
      raise exception 'EMPLOYEE_NOT_FOUND';
    elsif v_candidate_count > 1 then
      raise exception 'EMPLOYEE_CODE_AMBIGUOUS';
    end if;

    select e.*
      into v_employee
    from public.employees e
    where upper(e.employee_code) = upper(v_ref)
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type)
    limit 1;
  end if;

  -- Resolve department target
  if v_set_department then
    if p_payload ? 'department_id' then
      v_department_id := nullif(p_payload ->> 'department_id', '')::uuid;
    elsif v_department_name is not null then
      select count(*)::int
        into v_department_match_count
      from public.departments d
      where d.org_id = v_employee.org_id
        and d.company_id = v_employee.company_id
        and d.environment_type = v_employee.environment_type
        and lower(d.department_name) = lower(v_department_name)
        and d.is_active = true;

      if v_department_match_count = 0 then
        raise exception 'DEPARTMENT_NOT_FOUND';
      elsif v_department_match_count > 1 then
        raise exception 'DEPARTMENT_NAME_AMBIGUOUS';
      end if;

      select d.id
        into v_department_id
      from public.departments d
      where d.org_id = v_employee.org_id
        and d.company_id = v_employee.company_id
        and d.environment_type = v_employee.environment_type
        and lower(d.department_name) = lower(v_department_name)
        and d.is_active = true
      limit 1;
    else
      v_department_id := null;
    end if;

    if v_department_id is not null then
      perform 1
      from public.departments d
      where d.id = v_department_id
        and d.org_id = v_employee.org_id
        and d.company_id = v_employee.company_id
        and d.environment_type = v_employee.environment_type;

      if not found then
        raise exception 'DEPARTMENT_SCOPE_MISMATCH';
      end if;
    end if;
  end if;

  -- Resolve position target
  if v_set_position then
    if p_payload ? 'position_id' then
      v_position_id := nullif(p_payload ->> 'position_id', '')::uuid;
    elsif v_position_title is not null then
      select count(*)::int
        into v_position_match_count
      from public.positions p
      where p.org_id = v_employee.org_id
        and p.company_id = v_employee.company_id
        and p.environment_type = v_employee.environment_type
        and lower(p.position_name) = lower(v_position_title)
        and p.is_active = true;

      if v_position_match_count = 0 then
        raise exception 'POSITION_NOT_FOUND';
      elsif v_position_match_count > 1 then
        raise exception 'POSITION_TITLE_AMBIGUOUS';
      end if;

      select p.id
        into v_position_id
      from public.positions p
      where p.org_id = v_employee.org_id
        and p.company_id = v_employee.company_id
        and p.environment_type = v_employee.environment_type
        and lower(p.position_name) = lower(v_position_title)
        and p.is_active = true
      limit 1;
    else
      v_position_id := null;
    end if;

    if v_position_id is not null then
      perform 1
      from public.positions p
      where p.id = v_position_id
        and p.org_id = v_employee.org_id
        and p.company_id = v_employee.company_id
        and p.environment_type = v_employee.environment_type;

      if not found then
        raise exception 'POSITION_SCOPE_MISMATCH';
      end if;
    end if;
  end if;

  -- Resolve manager target
  if v_set_manager then
    v_manager_ref := nullif(trim(coalesce(p_payload ->> 'manager_employee_id', '')), '');

    if v_manager_ref is null then
      v_manager_employee_id := null;
    else
      begin
        v_manager_employee_id := v_manager_ref::uuid;
      exception
        when others then
          raise exception 'MANAGER_EMPLOYEE_ID_INVALID';
      end;

      if v_manager_employee_id = v_employee.id then
        raise exception 'MANAGER_SELF_NOT_ALLOWED';
      end if;

      perform 1
      from public.employees m
      where m.id = v_manager_employee_id
        and m.org_id = v_employee.org_id
        and m.company_id = v_employee.company_id
        and m.environment_type = v_employee.environment_type;

      if not found then
        raise exception 'MANAGER_SCOPE_MISMATCH';
      end if;
    end if;
  end if;

  if v_set_employment_type then
    v_employment_type := nullif(trim(coalesce(p_payload ->> 'employment_type', '')), '');
  end if;

  if v_set_employment_status then
    v_employment_status := nullif(trim(coalesce(p_payload ->> 'employment_status', '')), '');
  end if;

  if v_set_preferred_locale then
    v_preferred_locale := nullif(trim(coalesce(p_payload ->> 'preferred_locale', '')), '');
  end if;

  if v_set_timezone then
    v_timezone := nullif(trim(coalesce(p_payload ->> 'timezone', '')), '');
  end if;

  if v_set_hire_date then
    v_hire_date := nullif(p_payload ->> 'hire_date', '')::date;
  end if;

  update public.employees e
  set
    department_id = case when v_set_department then v_department_id else e.department_id end,
    position_id = case when v_set_position then v_position_id else e.position_id end,
    manager_employee_id = case when v_set_manager then v_manager_employee_id else e.manager_employee_id end,
    employment_type = case when v_set_employment_type then v_employment_type else e.employment_type end,
    employment_status = case when v_set_employment_status then v_employment_status else e.employment_status end,
    preferred_locale = case when v_set_preferred_locale then v_preferred_locale else e.preferred_locale end,
    timezone = case when v_set_timezone then v_timezone else e.timezone end,
    hire_date = case when v_set_hire_date then v_hire_date else e.hire_date end,
    updated_at = now(),
    updated_by = v_actor_user_id
  where e.id = v_employee.id
  returning * into v_updated;

  select *
    into v_detail
  from public.get_employee_detail(v_updated.id::text)
  limit 1;

  return jsonb_build_object(
    'employee_id', v_detail.employee_id,
    'employee_code', v_detail.employee_code,
    'full_name_local', v_detail.full_name_local,
    'full_name_latin', v_detail.full_name_latin,
    'preferred_locale', v_detail.preferred_locale,
    'timezone', v_detail.timezone,
    'employment_type', v_detail.employment_type,
    'employment_status', v_detail.employment_status,
    'department_name', v_detail.department_name,
    'position_title', v_detail.position_title,
    'manager_employee_id', v_detail.manager_employee_id,
    'manager_name', v_detail.manager_name,
    'direct_reports_count', v_detail.direct_reports_count,
    'hire_date', v_detail.hire_date,
    'avatar_url', v_detail.avatar_url,
    'updated_at', v_updated.updated_at
  );
end;
$$;

-- Org chart: roots resolver (derived from employee master)
drop function if exists public.list_org_chart_roots(uuid, uuid);
create function public.list_org_chart_roots(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  employee_id uuid,
  employee_code text,
  display_name text,
  full_name_local text,
  full_name_latin text,
  department_name text,
  position_title text,
  manager_employee_id uuid,
  direct_reports_count int,
  root_reason text,
  root_rank int
)
language sql
stable
security invoker
set search_path = public
as $$
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
  ),
  scoped as (
    select e.*
    from public.employees e
    where e.org_id = p_org_id
      and e.company_id = p_company_id
      and ((select resolved_env from env) is null or e.environment_type = (select resolved_env from env))
      and coalesce(e.employment_status, '') <> 'terminated'
  ),
  roots as (
    select
      e.*,
      case
        when e.manager_employee_id is null then 'no_manager'
        else 'manager_not_in_scope'
      end as root_reason
    from scoped e
    left join scoped m on m.id = e.manager_employee_id
    where e.manager_employee_id is null or m.id is null
  ),
  reports as (
    select
      e.manager_employee_id,
      count(*)::int as direct_reports_count
    from scoped e
    where e.manager_employee_id is not null
    group by e.manager_employee_id
  )
  select
    r.id as employee_id,
    r.employee_code,
    r.display_name,
    r.full_name_local,
    r.full_name_latin,
    d.department_name,
    p.position_name as position_title,
    r.manager_employee_id,
    coalesce(rep.direct_reports_count, 0)::int as direct_reports_count,
    r.root_reason,
    row_number() over (
      order by
        case when coalesce(p.is_managerial, false) then 0 else 1 end,
        coalesce(d.sort_order, 9999),
        coalesce(r.hire_date, date '9999-12-31'),
        r.employee_code
    )::int as root_rank
  from roots r
  left join reports rep on rep.manager_employee_id = r.id
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
  order by root_rank asc
$$;

-- Org chart: direct children resolver
drop function if exists public.list_org_chart_children(text);
create function public.list_org_chart_children(
  p_employee_id text
)
returns table (
  employee_id uuid,
  employee_code text,
  display_name text,
  full_name_local text,
  full_name_latin text,
  department_name text,
  position_title text,
  manager_employee_id uuid,
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
  with manager_target as (
    select e.*
    from public.employees e
    where (v_ref_uuid is not null and e.id = v_ref_uuid)
       or upper(e.employee_code) = upper(v_ref)
    order by case when v_ref_uuid is not null and e.id = v_ref_uuid then 0 else 1 end
    limit 1
  ),
  children as (
    select c.*
    from public.employees c
    join manager_target m
      on c.manager_employee_id = m.id
     and c.org_id = m.org_id
     and c.company_id = m.company_id
     and c.environment_type = m.environment_type
    where coalesce(c.employment_status, '') <> 'terminated'
  ),
  reports as (
    select
      c.manager_employee_id,
      count(*)::int as direct_reports_count
    from public.employees c
    join manager_target m
      on c.org_id = m.org_id
     and c.company_id = m.company_id
     and c.environment_type = m.environment_type
    where c.manager_employee_id is not null
    group by c.manager_employee_id
  )
  select
    c.id as employee_id,
    c.employee_code,
    c.display_name,
    c.full_name_local,
    c.full_name_latin,
    d.department_name,
    p.position_name as position_title,
    c.manager_employee_id,
    coalesce(r.direct_reports_count, 0)::int as direct_reports_count
  from children c
  left join reports r on r.manager_employee_id = c.id
  left join public.departments d
    on d.id = c.department_id
   and d.org_id = c.org_id
   and d.company_id = c.company_id
   and d.environment_type = c.environment_type
  left join public.positions p
    on p.id = c.position_id
   and p.org_id = c.org_id
   and p.company_id = c.company_id
   and p.environment_type = c.environment_type
  order by
    case when coalesce(p.is_managerial, false) then 0 else 1 end,
    coalesce(d.sort_order, 9999),
    coalesce(c.hire_date, date '9999-12-31'),
    c.employee_code;
end;
$$;

grant execute on function public.update_employee_profile(jsonb) to authenticated, service_role;
grant execute on function public.list_org_chart_roots(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_org_chart_children(text) to authenticated, service_role;

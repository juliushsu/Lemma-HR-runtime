-- Employee Master v2 minimal schema + read/write contract (staging)
-- Scope: keep compatibility, no production deployment in this change.

alter table public.employees
  add column if not exists gender text,
  add column if not exists birth_date date,
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_phone text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    where c.conname = 'employees_gender_check'
      and c.conrelid = 'public.employees'::regclass
  ) then
    alter table public.employees
      add constraint employees_gender_check
      check (
        gender is null
        or gender = any (array[
          'male'::text,
          'female'::text,
          'non_binary'::text,
          'prefer_not_to_say'::text,
          'other'::text
        ])
      );
  end if;
end
$$;

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
  avatar_url text,
  display_name text,
  gender text,
  nationality_code text,
  birth_date date,
  work_email text,
  personal_email text,
  mobile_phone text,
  emergency_contact_name text,
  emergency_contact_phone text
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
    null::text as avatar_url,
    t.display_name,
    t.gender,
    t.nationality_code,
    t.birth_date,
    t.work_email,
    t.personal_email,
    t.mobile_phone,
    t.emergency_contact_name,
    t.emergency_contact_phone
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
  v_set_full_name_local boolean := (p_payload ? 'full_name_local');
  v_set_full_name_latin boolean := (p_payload ? 'full_name_latin');
  v_set_display_name boolean := (p_payload ? 'display_name');
  v_set_gender boolean := (p_payload ? 'gender');
  v_set_nationality_code boolean := (p_payload ? 'nationality_code');
  v_set_birth_date boolean := (p_payload ? 'birth_date');
  v_set_emergency_contact_name boolean := (p_payload ? 'emergency_contact_name');
  v_set_emergency_contact_phone boolean := (p_payload ? 'emergency_contact_phone');

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
  v_full_name_local text;
  v_full_name_latin text;
  v_display_name text;
  v_gender text;
  v_nationality_code text;
  v_birth_date date;
  v_emergency_contact_name text;
  v_emergency_contact_phone text;

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

  if v_set_full_name_local then
    v_full_name_local := nullif(trim(coalesce(p_payload ->> 'full_name_local', '')), '');
  end if;

  if v_set_full_name_latin then
    v_full_name_latin := nullif(trim(coalesce(p_payload ->> 'full_name_latin', '')), '');
  end if;

  if v_set_display_name then
    v_display_name := nullif(trim(coalesce(p_payload ->> 'display_name', '')), '');
  end if;

  if v_set_gender then
    v_gender := nullif(trim(coalesce(p_payload ->> 'gender', '')), '');
  end if;

  if v_set_nationality_code then
    v_nationality_code := nullif(trim(coalesce(p_payload ->> 'nationality_code', '')), '');
  end if;

  if v_set_birth_date then
    v_birth_date := nullif(p_payload ->> 'birth_date', '')::date;
  end if;

  if v_set_emergency_contact_name then
    v_emergency_contact_name := nullif(trim(coalesce(p_payload ->> 'emergency_contact_name', '')), '');
  end if;

  if v_set_emergency_contact_phone then
    v_emergency_contact_phone := nullif(trim(coalesce(p_payload ->> 'emergency_contact_phone', '')), '');
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
    full_name_local = case when v_set_full_name_local then v_full_name_local else e.full_name_local end,
    full_name_latin = case when v_set_full_name_latin then v_full_name_latin else e.full_name_latin end,
    display_name = case when v_set_display_name then v_display_name else e.display_name end,
    gender = case when v_set_gender then v_gender else e.gender end,
    nationality_code = case when v_set_nationality_code then v_nationality_code else e.nationality_code end,
    birth_date = case when v_set_birth_date then v_birth_date else e.birth_date end,
    emergency_contact_name = case when v_set_emergency_contact_name then v_emergency_contact_name else e.emergency_contact_name end,
    emergency_contact_phone = case when v_set_emergency_contact_phone then v_emergency_contact_phone else e.emergency_contact_phone end,
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
    'display_name', v_detail.display_name,
    'full_name_local', v_detail.full_name_local,
    'full_name_latin', v_detail.full_name_latin,
    'gender', v_detail.gender,
    'nationality_code', v_detail.nationality_code,
    'birth_date', v_detail.birth_date,
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
    'emergency_contact_name', v_detail.emergency_contact_name,
    'emergency_contact_phone', v_detail.emergency_contact_phone,
    'avatar_url', v_detail.avatar_url,
    'updated_at', v_updated.updated_at
  );
end;
$$;

grant execute on function public.get_employee_detail(text) to authenticated, service_role;
grant execute on function public.update_employee_profile(jsonb) to authenticated, service_role;

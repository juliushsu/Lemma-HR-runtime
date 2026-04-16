-- Org chart resolver tree contract v1 (staging)
-- Purpose: provide hierarchy-ready read layer so frontend does not build tree logic itself.

drop function if exists public.list_org_chart_roots(uuid, uuid);
create function public.list_org_chart_roots(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  employee_id uuid,
  employee_code text,
  full_name_local text,
  full_name_latin text,
  department_name text,
  position_title text,
  manager_employee_id uuid,
  employment_status text,
  is_root boolean,
  has_children boolean,
  direct_reports_count int,
  node_type text,
  root_rank int
)
language sql
stable
security invoker
set search_path = public
as $$
  with recursive env as (
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
  direct_counts as (
    select manager_employee_id, count(*)::int as direct_reports_count
    from scoped
    where manager_employee_id is not null
    group by manager_employee_id
  ),
  roots as (
    select e.*
    from scoped e
    left join scoped m on m.id = e.manager_employee_id
    where e.manager_employee_id is null or m.id is null
  )
  select
    r.id as employee_id,
    r.employee_code,
    r.full_name_local,
    r.full_name_latin,
    d.department_name,
    p.position_name as position_title,
    r.manager_employee_id,
    r.employment_status,
    true as is_root,
    (coalesce(dc.direct_reports_count, 0) > 0) as has_children,
    coalesce(dc.direct_reports_count, 0)::int as direct_reports_count,
    'root'::text as node_type,
    row_number() over (
      order by
        case when coalesce(p.is_managerial, false) then 0 else 1 end,
        coalesce(d.sort_order, 9999),
        coalesce(r.hire_date, date '9999-12-31'),
        r.employee_code
    )::int as root_rank
  from roots r
  left join direct_counts dc on dc.manager_employee_id = r.id
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

drop function if exists public.list_org_chart_children(text);
create function public.list_org_chart_children(
  p_employee_id text
)
returns table (
  employee_id uuid,
  employee_code text,
  full_name_local text,
  full_name_latin text,
  department_name text,
  position_title text,
  manager_employee_id uuid,
  employment_status text,
  is_root boolean,
  has_children boolean,
  direct_reports_count int,
  node_type text
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
  scoped as (
    select c.*
    from public.employees c
    join manager_target m
      on c.org_id = m.org_id
     and c.company_id = m.company_id
     and c.environment_type = m.environment_type
    where coalesce(c.employment_status, '') <> 'terminated'
  ),
  children as (
    select c.*
    from scoped c
    join manager_target m on c.manager_employee_id = m.id
  ),
  direct_counts as (
    select s.manager_employee_id, count(*)::int as direct_reports_count
    from scoped s
    where s.manager_employee_id is not null
    group by s.manager_employee_id
  )
  select
    c.id as employee_id,
    c.employee_code,
    c.full_name_local,
    c.full_name_latin,
    d.department_name,
    p.position_name as position_title,
    c.manager_employee_id,
    c.employment_status,
    false as is_root,
    (coalesce(dc.direct_reports_count, 0) > 0) as has_children,
    coalesce(dc.direct_reports_count, 0)::int as direct_reports_count,
    case when coalesce(dc.direct_reports_count, 0) > 0 then 'manager' else 'staff' end::text as node_type
  from children c
  left join direct_counts dc on dc.manager_employee_id = c.id
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

drop function if exists public.get_org_chart_tree(uuid, uuid);
create function public.get_org_chart_tree(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  employee_id uuid,
  employee_code text,
  full_name_local text,
  full_name_latin text,
  department_name text,
  position_title text,
  manager_employee_id uuid,
  employment_status text,
  is_root boolean,
  has_children boolean,
  direct_reports_count int,
  node_type text,
  depth int,
  root_employee_id uuid,
  sort_path text
)
language sql
stable
security invoker
set search_path = public
as $$
  with recursive env as (
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
  direct_counts as (
    select manager_employee_id, count(*)::int as direct_reports_count
    from scoped
    where manager_employee_id is not null
    group by manager_employee_id
  ),
  roots as (
    select
      e.id,
      row_number() over (
        order by
          case when coalesce(p.is_managerial, false) then 0 else 1 end,
          coalesce(d.sort_order, 9999),
          coalesce(e.hire_date, date '9999-12-31'),
          e.employee_code
      )::int as root_rank
    from scoped e
    left join scoped m on m.id = e.manager_employee_id
    left join public.departments d
      on d.id = e.department_id
     and d.org_id = e.org_id
     and d.company_id = e.company_id
     and d.environment_type = e.environment_type
    left join public.positions p
      on p.id = e.position_id
     and p.org_id = e.org_id
     and p.company_id = e.company_id
     and p.environment_type = e.environment_type
    where e.manager_employee_id is null or m.id is null
  ),
  tree as (
    select
      e.id,
      e.org_id,
      e.company_id,
      e.environment_type,
      e.employee_code,
      e.full_name_local,
      e.full_name_latin,
      e.department_id,
      e.position_id,
      e.manager_employee_id,
      e.employment_status,
      true as is_root,
      coalesce(dc.direct_reports_count, 0)::int as direct_reports_count,
      case when coalesce(dc.direct_reports_count, 0) > 0 then 'root' else 'root' end::text as node_type,
      0::int as depth,
      e.id as root_employee_id,
      lpad(coalesce(r.root_rank, 9999)::text, 4, '0') || ':' || e.employee_code as sort_path,
      array[e.id]::uuid[] as path
    from scoped e
    join roots r on r.id = e.id
    left join direct_counts dc on dc.manager_employee_id = e.id

    union all

    select
      c.id,
      c.org_id,
      c.company_id,
      c.environment_type,
      c.employee_code,
      c.full_name_local,
      c.full_name_latin,
      c.department_id,
      c.position_id,
      c.manager_employee_id,
      c.employment_status,
      false as is_root,
      coalesce(dc.direct_reports_count, 0)::int as direct_reports_count,
      case when coalesce(dc.direct_reports_count, 0) > 0 then 'manager' else 'staff' end::text as node_type,
      t.depth + 1,
      t.root_employee_id,
      t.sort_path || '>' || c.employee_code,
      t.path || c.id
    from scoped c
    join tree t on c.manager_employee_id = t.id
    left join direct_counts dc on dc.manager_employee_id = c.id
    where not (c.id = any(t.path))
  )
  select
    t.id as employee_id,
    t.employee_code,
    t.full_name_local,
    t.full_name_latin,
    d.department_name,
    p.position_name as position_title,
    t.manager_employee_id,
    t.employment_status,
    t.is_root,
    (t.direct_reports_count > 0) as has_children,
    t.direct_reports_count,
    t.node_type,
    t.depth,
    t.root_employee_id,
    t.sort_path
  from tree t
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
  order by t.sort_path
$$;

grant execute on function public.list_org_chart_roots(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_org_chart_children(text) to authenticated, service_role;
grant execute on function public.get_org_chart_tree(uuid, uuid) to authenticated, service_role;

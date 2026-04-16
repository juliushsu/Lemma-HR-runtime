-- Settings read layer (contract_v1) for frontend adapters
-- Scope: read-only SQL functions, no schema-breaking changes

create or replace function public.get_company_profile(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  company_legal_name text,
  tax_id text,
  address text,
  default_locale text,
  timezone text,
  is_attendance_enabled boolean,
  updated_at timestamptz,
  data_source_status text
)
language sql
stable
security invoker
set search_path = public
as $$
  with anchor as (
    select 1 as k
  ),
  company_row as (
    select c.id, c.org_id, c.name, c.locale_default, c.environment_type, c.updated_at
    from public.companies c
    where c.org_id = p_org_id
      and c.id = p_company_id
    order by c.updated_at desc nulls last
    limit 1
  ),
  settings_row as (
    select cs.*
    from public.company_settings cs
    join company_row c
      on c.org_id = cs.org_id
     and c.id = cs.company_id
     and c.environment_type = cs.environment_type
    order by cs.updated_at desc nulls last
    limit 1
  ),
  org_row as (
    select o.id, o.locale_default, o.updated_at
    from public.organizations o
    where o.id = p_org_id
    order by o.updated_at desc nulls last
    limit 1
  )
  select
    coalesce(s.company_legal_name, c.name, null) as company_legal_name,
    s.tax_id,
    s.address,
    coalesce(s.default_locale, c.locale_default, o.locale_default, 'en') as default_locale,
    coalesce(s.timezone, 'Asia/Taipei') as timezone,
    coalesce(s.is_attendance_enabled, true) as is_attendance_enabled,
    coalesce(s.updated_at, c.updated_at, o.updated_at, null) as updated_at,
    case
      when s.id is not null then 'company_settings'
      when c.id is not null then 'fallback_companies'
      when o.id is not null then 'fallback_organizations'
      else 'missing'
    end as data_source_status
  from anchor a
  left join company_row c on true
  left join settings_row s on true
  left join org_row o on true;
$$;

create or replace function public.get_branch_settings(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  branch_id uuid,
  branch_name text,
  latitude numeric,
  longitude numeric,
  is_attendance_enabled boolean,
  has_gps boolean,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    b.id as branch_id,
    b.name as branch_name,
    b.latitude,
    b.longitude,
    coalesce(bo.is_attendance_enabled, b.is_attendance_enabled, cd.is_attendance_enabled, true) as is_attendance_enabled,
    (b.latitude is not null and b.longitude is not null) as has_gps,
    coalesce(bo.updated_at, b.updated_at, cd.updated_at, null) as updated_at
  from public.branches b
  left join lateral (
    select abs.is_attendance_enabled, abs.updated_at
    from public.attendance_boundary_settings abs
    where abs.org_id = b.org_id
      and abs.company_id = b.company_id
      and abs.environment_type = b.environment_type
      and abs.branch_id = b.id
    order by abs.updated_at desc nulls last
    limit 1
  ) bo on true
  left join lateral (
    select abs.is_attendance_enabled, abs.updated_at
    from public.attendance_boundary_settings abs
    where abs.org_id = b.org_id
      and abs.company_id = b.company_id
      and abs.environment_type = b.environment_type
      and abs.branch_id is null
    order by abs.updated_at desc nulls last
    limit 1
  ) cd on true
  where b.org_id = p_org_id
    and b.company_id = p_company_id
  order by b.created_at asc, b.id asc;
$$;

create or replace function public.get_attendance_sources(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  source_id uuid,
  source_type text,
  source_name text,
  auth_mode text,
  is_enabled boolean,
  last_validated_at timestamptz,
  status_label text
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    s.id as source_id,
    s.source_type,
    s.source_name,
    s.auth_mode,
    s.is_enabled,
    s.last_validated_at,
    case
      when s.is_enabled = false then 'disabled'
      when s.last_validated_at is null then 'enabled_unvalidated'
      else 'enabled_validated'
    end as status_label
  from public.attendance_source_registry s
  where s.org_id = p_org_id
    and s.company_id = p_company_id
  order by s.created_at desc, s.id desc;
$$;

create or replace function public.get_line_binding_summary(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  total_bindings bigint,
  active_bindings bigint,
  pending_tokens bigint,
  expired_tokens bigint,
  last_event_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with binding_stats as (
    select
      count(*)::bigint as total_bindings,
      count(*) filter (where bind_status = 'active')::bigint as active_bindings
    from public.line_bindings b
    where b.org_id = p_org_id
      and b.company_id = p_company_id
  ),
  token_stats as (
    select
      count(*) filter (
        where t.status = 'pending'
          and t.consumed_at is null
          and t.expires_at > now()
      )::bigint as pending_tokens,
      count(*) filter (
        where t.status = 'expired'
           or (
             t.status = 'pending'
             and t.consumed_at is null
             and t.expires_at <= now()
           )
      )::bigint as expired_tokens
    from public.line_binding_tokens t
    where t.org_id = p_org_id
      and t.company_id = p_company_id
  ),
  event_stats as (
    select max(l.created_at) as last_event_at
    from public.line_webhook_event_logs l
    where l.org_id = p_org_id
      and l.company_id = p_company_id
  )
  select
    coalesce(b.total_bindings, 0)::bigint as total_bindings,
    coalesce(b.active_bindings, 0)::bigint as active_bindings,
    coalesce(t.pending_tokens, 0)::bigint as pending_tokens,
    coalesce(t.expired_tokens, 0)::bigint as expired_tokens,
    e.last_event_at
  from binding_stats b
  cross join token_stats t
  cross join event_stats e;
$$;

revoke all on function public.get_company_profile(uuid, uuid) from public;
revoke all on function public.get_branch_settings(uuid, uuid) from public;
revoke all on function public.get_attendance_sources(uuid, uuid) from public;
revoke all on function public.get_line_binding_summary(uuid, uuid) from public;

grant execute on function public.get_company_profile(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_branch_settings(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_attendance_sources(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_line_binding_summary(uuid, uuid) to authenticated, service_role;

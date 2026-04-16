-- Leave policy engine read/write layer v1 (staging rollout target)

alter table public.leave_compliance_warnings
  add column if not exists resolution_note text;

create or replace function public.leave_policy_resolve_environment(
  p_org_id uuid,
  p_company_id uuid
)
returns text
language sql
stable
as $$
  select m.environment_type::text
  from public.memberships m
  where m.user_id = auth.uid()
    and m.org_id = p_org_id
    and (m.company_id is null or m.company_id = p_company_id)
  order by
    case m.environment_type::text
      when 'demo' then 1
      when 'production' then 2
      else 9
    end,
    m.created_at asc
  limit 1
$$;

create or replace function public.leave_policy_active_profile_id(
  p_org_id uuid,
  p_company_id uuid,
  p_environment_type text
)
returns uuid
language sql
stable
as $$
  select p.id
  from public.leave_policy_profiles p
  where p.org_id = p_org_id
    and p.company_id = p_company_id
    and p.environment_type = p_environment_type
    and p.effective_from <= current_date
    and (p.effective_to is null or p.effective_to >= current_date)
  order by p.effective_from desc, p.updated_at desc
  limit 1
$$;

drop function if exists public.get_leave_policy_profile(uuid, uuid);
create function public.get_leave_policy_profile(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  policy_profile_id uuid,
  org_id uuid,
  company_id uuid,
  environment_type text,
  is_demo boolean,
  country_code text,
  policy_name text,
  effective_from date,
  effective_to date,
  leave_year_mode text,
  holiday_mode text,
  allow_cross_country_holiday_merge boolean,
  payroll_policy_mode text,
  compliance_warning_enabled boolean,
  notes text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
  )
  select
    p.id as policy_profile_id,
    p.org_id,
    p.company_id,
    p.environment_type,
    p.is_demo,
    p.country_code,
    p.policy_name,
    p.effective_from,
    p.effective_to,
    p.leave_year_mode,
    p.holiday_mode,
    p.allow_cross_country_holiday_merge,
    p.payroll_policy_mode,
    p.compliance_warning_enabled,
    p.notes,
    p.created_at,
    p.updated_at
  from public.leave_policy_profiles p
  cross join env
  where p.org_id = p_org_id
    and p.company_id = p_company_id
    and (env.resolved_env is null or p.environment_type = env.resolved_env)
  order by
    case when p.effective_from <= current_date and (p.effective_to is null or p.effective_to >= current_date) then 0 else 1 end,
    p.effective_from desc,
    p.updated_at desc
  limit 1
$$;

drop function if exists public.list_leave_types(uuid, uuid);
create function public.list_leave_types(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  leave_type_id uuid,
  leave_policy_profile_id uuid,
  leave_type_code text,
  display_name text,
  is_paid boolean,
  affects_payroll boolean,
  requires_attachment boolean,
  requires_approval boolean,
  sort_order int,
  is_enabled boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
  ),
  active_profile as (
    select
      case
        when (select resolved_env from env) is not null
          then public.leave_policy_active_profile_id(p_org_id, p_company_id, (select resolved_env from env))
        else (
          select p.id
          from public.leave_policy_profiles p
          where p.org_id = p_org_id
            and p.company_id = p_company_id
          order by
            case when p.effective_from <= current_date and (p.effective_to is null or p.effective_to >= current_date) then 0 else 1 end,
            p.effective_from desc,
            p.updated_at desc
          limit 1
        )
      end as profile_id
  )
  select
    t.id as leave_type_id,
    t.leave_policy_profile_id,
    t.leave_type_code,
    t.display_name,
    t.is_paid,
    t.affects_payroll,
    t.requires_attachment,
    t.requires_approval,
    t.sort_order,
    t.is_enabled,
    t.created_at,
    t.updated_at
  from public.leave_types t
  where t.org_id = p_org_id
    and t.company_id = p_company_id
    and ((select resolved_env from env) is null or t.environment_type = (select resolved_env from env))
    and (
      (select profile_id from active_profile) is null
      or t.leave_policy_profile_id = (select profile_id from active_profile)
    )
  order by t.sort_order asc, t.display_name asc
$$;

drop function if exists public.list_leave_entitlement_rules(uuid, uuid);
create function public.list_leave_entitlement_rules(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  rule_id uuid,
  leave_policy_profile_id uuid,
  leave_type_code text,
  accrual_mode text,
  tenure_months_from int,
  tenure_months_to int,
  granted_days numeric,
  max_days_cap numeric,
  carry_forward_mode text,
  carry_forward_days numeric,
  effective_from date,
  effective_to date,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
  ),
  active_profile as (
    select
      case
        when (select resolved_env from env) is not null
          then public.leave_policy_active_profile_id(p_org_id, p_company_id, (select resolved_env from env))
        else (
          select p.id
          from public.leave_policy_profiles p
          where p.org_id = p_org_id
            and p.company_id = p_company_id
          order by
            case when p.effective_from <= current_date and (p.effective_to is null or p.effective_to >= current_date) then 0 else 1 end,
            p.effective_from desc,
            p.updated_at desc
          limit 1
        )
      end as profile_id
  )
  select
    r.id as rule_id,
    r.leave_policy_profile_id,
    r.leave_type_code,
    r.accrual_mode,
    r.tenure_months_from,
    r.tenure_months_to,
    r.granted_days,
    r.max_days_cap,
    r.carry_forward_mode,
    r.carry_forward_days,
    r.effective_from,
    r.effective_to,
    r.created_at,
    r.updated_at
  from public.leave_entitlement_rules r
  where r.org_id = p_org_id
    and r.company_id = p_company_id
    and ((select resolved_env from env) is null or r.environment_type = (select resolved_env from env))
    and (
      (select profile_id from active_profile) is null
      or r.leave_policy_profile_id = (select profile_id from active_profile)
    )
  order by r.leave_type_code asc, r.tenure_months_from asc, r.effective_from asc
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
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
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
  where s.org_id = p_org_id
    and s.company_id = p_company_id
    and ((select resolved_env from env) is null or s.environment_type = (select resolved_env from env))
  order by s.country_code asc, s.source_type asc, s.source_name asc
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
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
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
  where d.org_id = p_org_id
    and d.company_id = p_company_id
    and ((select resolved_env from env) is null or d.environment_type = (select resolved_env from env))
    and (p_from_date is null or d.holiday_date >= p_from_date)
    and (p_to_date is null or d.holiday_date <= p_to_date)
  order by d.holiday_date asc, d.holiday_name asc
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
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
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
  where w.org_id = p_org_id
    and w.company_id = p_company_id
    and ((select resolved_env from env) is null or w.environment_type = (select resolved_env from env))
  order by w.is_resolved asc, w.severity desc, w.created_at desc
$$;

drop function if exists public.list_leave_policy_decisions(uuid, uuid);
create function public.list_leave_policy_decisions(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  decision_id uuid,
  policy_profile_id uuid,
  decision_type text,
  decision_title text,
  decision_note text,
  approved_by uuid,
  approved_at timestamptz,
  attachment_ref text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with env as (
    select public.leave_policy_resolve_environment(p_org_id, p_company_id) as resolved_env
  )
  select
    d.id as decision_id,
    d.policy_profile_id,
    d.decision_type,
    d.decision_title,
    d.decision_note,
    d.approved_by,
    d.approved_at,
    d.attachment_ref,
    d.created_at,
    d.updated_at
  from public.leave_policy_decisions d
  where d.org_id = p_org_id
    and d.company_id = p_company_id
    and ((select resolved_env from env) is null or d.environment_type = (select resolved_env from env))
  order by d.approved_at desc, d.created_at desc
$$;

drop function if exists public.upsert_leave_policy_profile(jsonb);
create function public.upsert_leave_policy_profile(
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
  v_environment_type text := coalesce(nullif(p_payload ->> 'environment_type', ''), public.leave_policy_resolve_environment(v_org_id, v_company_id), 'production');
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

  return jsonb_build_object(
    'policy_profile_id', v_row.id,
    'org_id', v_row.org_id,
    'company_id', v_row.company_id,
    'environment_type', v_row.environment_type,
    'country_code', v_row.country_code,
    'policy_name', v_row.policy_name,
    'effective_from', v_row.effective_from,
    'effective_to', v_row.effective_to,
    'updated_at', v_row.updated_at
  );
end;
$$;

drop function if exists public.upsert_leave_type(jsonb);
create function public.upsert_leave_type(
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
  v_profile_id uuid := nullif(p_payload ->> 'leave_policy_profile_id', '')::uuid;
  v_profile public.leave_policy_profiles%rowtype;
  v_environment_type text;
  v_is_demo boolean;
  v_leave_type_code text := nullif(trim(coalesce(p_payload ->> 'leave_type_code', '')), '');
  v_display_name text := nullif(trim(coalesce(p_payload ->> 'display_name', '')), '');
  v_is_paid boolean := coalesce((p_payload ->> 'is_paid')::boolean, true);
  v_affects_payroll boolean := coalesce((p_payload ->> 'affects_payroll')::boolean, false);
  v_requires_attachment boolean := coalesce((p_payload ->> 'requires_attachment')::boolean, false);
  v_requires_approval boolean := coalesce((p_payload ->> 'requires_approval')::boolean, true);
  v_sort_order int := coalesce((p_payload ->> 'sort_order')::int, 100);
  v_is_enabled boolean := coalesce((p_payload ->> 'is_enabled')::boolean, true);
  v_actor_user_id uuid := auth.uid();
  v_row public.leave_types%rowtype;
begin
  if v_org_id is null or v_company_id is null or v_profile_id is null then
    raise exception 'TYPE_SCOPE_REQUIRED';
  end if;
  if v_leave_type_code is null or v_display_name is null then
    raise exception 'TYPE_REQUIRED_FIELDS_MISSING';
  end if;

  select *
    into v_profile
  from public.leave_policy_profiles p
  where p.id = v_profile_id
    and p.org_id = v_org_id
    and p.company_id = v_company_id;

  if not found then
    raise exception 'POLICY_PROFILE_NOT_FOUND';
  end if;

  v_environment_type := v_profile.environment_type;
  v_is_demo := v_profile.is_demo;

  insert into public.leave_types (
    id,
    org_id,
    company_id,
    leave_policy_profile_id,
    environment_type,
    is_demo,
    leave_type_code,
    display_name,
    is_paid,
    affects_payroll,
    requires_attachment,
    requires_approval,
    sort_order,
    is_enabled,
    created_at,
    updated_at,
    created_by,
    updated_by
  ) values (
    v_id,
    v_org_id,
    v_company_id,
    v_profile_id,
    v_environment_type,
    v_is_demo,
    v_leave_type_code,
    v_display_name,
    v_is_paid,
    v_affects_payroll,
    v_requires_attachment,
    v_requires_approval,
    v_sort_order,
    v_is_enabled,
    now(),
    now(),
    v_actor_user_id,
    v_actor_user_id
  )
  on conflict (org_id, company_id, leave_policy_profile_id, leave_type_code, environment_type)
  do update set
    display_name = excluded.display_name,
    is_paid = excluded.is_paid,
    affects_payroll = excluded.affects_payroll,
    requires_attachment = excluded.requires_attachment,
    requires_approval = excluded.requires_approval,
    sort_order = excluded.sort_order,
    is_enabled = excluded.is_enabled,
    updated_at = now(),
    updated_by = excluded.updated_by
  returning *
    into v_row;

  return jsonb_build_object(
    'leave_type_id', v_row.id,
    'leave_policy_profile_id', v_row.leave_policy_profile_id,
    'leave_type_code', v_row.leave_type_code,
    'display_name', v_row.display_name,
    'requires_attachment', v_row.requires_attachment,
    'requires_approval', v_row.requires_approval,
    'affects_payroll', v_row.affects_payroll,
    'updated_at', v_row.updated_at
  );
end;
$$;

drop function if exists public.upsert_leave_entitlement_rule(jsonb);
create function public.upsert_leave_entitlement_rule(
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
  v_profile_id uuid := nullif(p_payload ->> 'leave_policy_profile_id', '')::uuid;
  v_profile public.leave_policy_profiles%rowtype;
  v_environment_type text;
  v_is_demo boolean;
  v_leave_type_code text := nullif(trim(coalesce(p_payload ->> 'leave_type_code', '')), '');
  v_accrual_mode text := nullif(trim(coalesce(p_payload ->> 'accrual_mode', '')), '');
  v_tenure_from int := coalesce((p_payload ->> 'tenure_months_from')::int, 0);
  v_tenure_to int := nullif(p_payload ->> 'tenure_months_to', '')::int;
  v_granted_days numeric := nullif(p_payload ->> 'granted_days', '')::numeric;
  v_max_days_cap numeric := nullif(p_payload ->> 'max_days_cap', '')::numeric;
  v_carry_forward_mode text := nullif(trim(coalesce(p_payload ->> 'carry_forward_mode', '')), '');
  v_carry_forward_days numeric := nullif(p_payload ->> 'carry_forward_days', '')::numeric;
  v_effective_from date := nullif(p_payload ->> 'effective_from', '')::date;
  v_effective_to date := nullif(p_payload ->> 'effective_to', '')::date;
  v_actor_user_id uuid := auth.uid();
  v_row public.leave_entitlement_rules%rowtype;
begin
  if v_org_id is null or v_company_id is null or v_profile_id is null then
    raise exception 'RULE_SCOPE_REQUIRED';
  end if;
  if v_leave_type_code is null or v_accrual_mode is null or v_granted_days is null or v_effective_from is null then
    raise exception 'RULE_REQUIRED_FIELDS_MISSING';
  end if;

  select *
    into v_profile
  from public.leave_policy_profiles p
  where p.id = v_profile_id
    and p.org_id = v_org_id
    and p.company_id = v_company_id;

  if not found then
    raise exception 'POLICY_PROFILE_NOT_FOUND';
  end if;

  v_environment_type := v_profile.environment_type;
  v_is_demo := v_profile.is_demo;

  insert into public.leave_entitlement_rules (
    id,
    org_id,
    company_id,
    leave_policy_profile_id,
    environment_type,
    is_demo,
    leave_type_code,
    accrual_mode,
    tenure_months_from,
    tenure_months_to,
    granted_days,
    max_days_cap,
    carry_forward_mode,
    carry_forward_days,
    effective_from,
    effective_to,
    created_at,
    updated_at,
    created_by,
    updated_by
  ) values (
    v_id,
    v_org_id,
    v_company_id,
    v_profile_id,
    v_environment_type,
    v_is_demo,
    v_leave_type_code,
    v_accrual_mode,
    v_tenure_from,
    v_tenure_to,
    v_granted_days,
    v_max_days_cap,
    v_carry_forward_mode,
    v_carry_forward_days,
    v_effective_from,
    v_effective_to,
    now(),
    now(),
    v_actor_user_id,
    v_actor_user_id
  )
  on conflict (org_id, company_id, leave_policy_profile_id, leave_type_code, accrual_mode, tenure_months_from, effective_from, environment_type)
  do update set
    tenure_months_to = excluded.tenure_months_to,
    granted_days = excluded.granted_days,
    max_days_cap = excluded.max_days_cap,
    carry_forward_mode = excluded.carry_forward_mode,
    carry_forward_days = excluded.carry_forward_days,
    effective_to = excluded.effective_to,
    updated_at = now(),
    updated_by = excluded.updated_by
  returning *
    into v_row;

  return jsonb_build_object(
    'rule_id', v_row.id,
    'leave_policy_profile_id', v_row.leave_policy_profile_id,
    'leave_type_code', v_row.leave_type_code,
    'accrual_mode', v_row.accrual_mode,
    'tenure_months_from', v_row.tenure_months_from,
    'tenure_months_to', v_row.tenure_months_to,
    'granted_days', v_row.granted_days,
    'updated_at', v_row.updated_at
  );
end;
$$;

drop function if exists public.resolve_leave_compliance_warning(uuid, uuid, text);
create function public.resolve_leave_compliance_warning(
  p_warning_id uuid,
  p_actor_user_id uuid,
  p_resolution_note text default null
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := coalesce(auth.uid(), p_actor_user_id);
  v_row public.leave_compliance_warnings%rowtype;
begin
  if auth.uid() is not null and p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'ACTOR_USER_MISMATCH';
  end if;
  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_REQUIRED';
  end if;

  update public.leave_compliance_warnings w
  set
    is_resolved = true,
    resolved_at = now(),
    resolved_by = v_actor_user_id,
    resolution_note = nullif(trim(coalesce(p_resolution_note, '')), ''),
    updated_at = now(),
    updated_by = v_actor_user_id
  where w.id = p_warning_id
  returning *
    into v_row;

  if not found then
    raise exception 'WARNING_NOT_FOUND';
  end if;

  return jsonb_build_object(
    'warning_id', v_row.id,
    'is_resolved', v_row.is_resolved,
    'resolved_at', v_row.resolved_at,
    'resolved_by', v_row.resolved_by,
    'resolution_note', v_row.resolution_note,
    'updated_at', v_row.updated_at
  );
end;
$$;

grant execute on function public.get_leave_policy_profile(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_leave_types(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_leave_entitlement_rules(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_holiday_calendar_sources(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_holiday_calendar_days(uuid, uuid, date, date) to authenticated, service_role;
grant execute on function public.list_leave_compliance_warnings(uuid, uuid) to authenticated, service_role;
grant execute on function public.list_leave_policy_decisions(uuid, uuid) to authenticated, service_role;
grant execute on function public.upsert_leave_policy_profile(jsonb) to authenticated, service_role;
grant execute on function public.upsert_leave_type(jsonb) to authenticated, service_role;
grant execute on function public.upsert_leave_entitlement_rule(jsonb) to authenticated, service_role;
grant execute on function public.resolve_leave_compliance_warning(uuid, uuid, text) to authenticated, service_role;

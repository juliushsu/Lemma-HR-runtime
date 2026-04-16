-- Leave Policy Engine minimal schema + baseline RLS (staging rollout target)
-- Scope: policy profile / leave types / entitlement rules / holiday sources & days / compliance warnings / policy decisions

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
create or replace function public.leave_policy_can_read(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type text
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type::text = row_environment_type
      and m.role::text in ('owner', 'super_admin', 'admin', 'manager', 'operator', 'viewer')
      and m.scope_type::text in ('org', 'company')
  )
$$;

create or replace function public.leave_policy_can_write(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type text
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type::text = row_environment_type
      and m.role::text in ('owner', 'admin', 'manager')
      and m.scope_type::text in ('org', 'company')
  )
$$;

create or replace function public.leave_policy_can_read_global(
  row_environment_type text
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.environment_type::text = row_environment_type
      and m.role::text in ('owner', 'super_admin', 'admin', 'manager', 'operator', 'viewer')
  )
$$;

-- -----------------------------------------------------------------------------
-- 1) leave_policy_profiles
-- -----------------------------------------------------------------------------
create table if not exists public.leave_policy_profiles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  environment_type text not null default 'production' check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  country_code text not null,
  policy_name text not null,
  effective_from date not null,
  effective_to date,
  leave_year_mode text not null check (leave_year_mode in ('calendar_year', 'anniversary_year', 'custom')),
  holiday_mode text not null check (holiday_mode in ('official_calendar', 'shift_based', 'hybrid')),
  allow_cross_country_holiday_merge boolean not null default false,
  payroll_policy_mode text not null check (payroll_policy_mode in ('strict', 'custom')),
  compliance_warning_enabled boolean not null default true,
  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  check (effective_to is null or effective_to >= effective_from),
  unique (org_id, company_id, country_code, policy_name, effective_from, environment_type),
  unique (id, org_id, company_id, environment_type)
);

create index if not exists leave_policy_profiles_scope_idx
  on public.leave_policy_profiles (org_id, company_id, environment_type, effective_from desc);

-- -----------------------------------------------------------------------------
-- 2) leave_types
-- -----------------------------------------------------------------------------
create table if not exists public.leave_types (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  leave_policy_profile_id uuid not null,
  environment_type text not null default 'production' check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  leave_type_code text not null,
  display_name text not null,
  is_paid boolean not null default true,
  affects_payroll boolean not null default false,
  requires_attachment boolean not null default false,
  requires_approval boolean not null default true,
  sort_order int not null default 100,
  is_enabled boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  constraint leave_types_profile_scope_fkey
    foreign key (leave_policy_profile_id, org_id, company_id, environment_type)
    references public.leave_policy_profiles(id, org_id, company_id, environment_type)
    on delete cascade,
  unique (org_id, company_id, leave_policy_profile_id, leave_type_code, environment_type)
);

create index if not exists leave_types_scope_idx
  on public.leave_types (org_id, company_id, environment_type, is_enabled, sort_order);

-- -----------------------------------------------------------------------------
-- 3) leave_entitlement_rules
-- -----------------------------------------------------------------------------
create table if not exists public.leave_entitlement_rules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  leave_policy_profile_id uuid not null,
  environment_type text not null default 'production' check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  leave_type_code text not null,
  accrual_mode text not null check (accrual_mode in ('anniversary', 'calendar', 'monthly', 'manual')),
  tenure_months_from int not null default 0,
  tenure_months_to int,
  granted_days numeric(10,2) not null,
  max_days_cap numeric(10,2),
  carry_forward_mode text not null check (carry_forward_mode in ('none', 'limited', 'custom')),
  carry_forward_days numeric(10,2),
  effective_from date not null,
  effective_to date,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  constraint leave_entitlement_rules_profile_scope_fkey
    foreign key (leave_policy_profile_id, org_id, company_id, environment_type)
    references public.leave_policy_profiles(id, org_id, company_id, environment_type)
    on delete cascade,
  check (tenure_months_to is null or tenure_months_to >= tenure_months_from),
  check (effective_to is null or effective_to >= effective_from),
  check (granted_days >= 0),
  check (max_days_cap is null or max_days_cap >= 0),
  check (carry_forward_days is null or carry_forward_days >= 0),
  unique (org_id, company_id, leave_policy_profile_id, leave_type_code, accrual_mode, tenure_months_from, effective_from, environment_type)
);

create index if not exists leave_entitlement_rules_scope_idx
  on public.leave_entitlement_rules (org_id, company_id, environment_type, leave_policy_profile_id, leave_type_code, effective_from desc);

-- -----------------------------------------------------------------------------
-- 4) holiday_calendar_sources
-- -----------------------------------------------------------------------------
create table if not exists public.holiday_calendar_sources (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  environment_type text not null default 'production' check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  country_code text not null,
  source_type text not null check (source_type in ('official_api', 'uploaded_calendar', 'manual')),
  source_name text not null,
  source_ref text,
  is_enabled boolean not null default true,
  last_synced_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, country_code, source_type, source_name, environment_type),
  unique (id, org_id, company_id, environment_type)
);

create index if not exists holiday_calendar_sources_scope_idx
  on public.holiday_calendar_sources (org_id, company_id, environment_type, country_code, is_enabled);

-- -----------------------------------------------------------------------------
-- 5) holiday_calendar_days
-- -----------------------------------------------------------------------------
create table if not exists public.holiday_calendar_days (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade,
  company_id uuid references public.companies(id) on delete cascade,
  environment_type text not null default 'production' check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  country_code text not null,
  holiday_date date not null,
  holiday_name text not null,
  holiday_category text not null check (holiday_category in ('national', 'company_extra', 'merged', 'substitute')),
  is_paid_day_off boolean not null default true,
  source_id uuid,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  constraint holiday_calendar_days_source_scope_fkey
    foreign key (source_id, org_id, company_id, environment_type)
    references public.holiday_calendar_sources(id, org_id, company_id, environment_type)
    on delete set null,
  check (company_id is null or org_id is not null),
  unique (org_id, company_id, country_code, holiday_date, holiday_name, holiday_category, environment_type)
);

create index if not exists holiday_calendar_days_scope_idx
  on public.holiday_calendar_days (country_code, holiday_date, environment_type, org_id, company_id);

-- -----------------------------------------------------------------------------
-- 6) leave_compliance_warnings
-- -----------------------------------------------------------------------------
create table if not exists public.leave_compliance_warnings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  policy_profile_id uuid,
  environment_type text not null default 'production' check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  warning_type text not null,
  severity text not null check (severity in ('info', 'warning', 'critical')),
  title text not null,
  message text not null,
  country_code text not null,
  related_rule_ref text,
  is_resolved boolean not null default false,
  resolved_at timestamptz,
  resolved_by uuid references public.users(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  constraint leave_compliance_warnings_profile_scope_fkey
    foreign key (policy_profile_id, org_id, company_id, environment_type)
    references public.leave_policy_profiles(id, org_id, company_id, environment_type)
    on delete set null,
  check ((is_resolved = false and resolved_at is null) or (is_resolved = true and resolved_at is not null))
);

create index if not exists leave_compliance_warnings_scope_idx
  on public.leave_compliance_warnings (org_id, company_id, environment_type, is_resolved, severity, created_at desc);

-- -----------------------------------------------------------------------------
-- 7) leave_policy_decisions
-- -----------------------------------------------------------------------------
create table if not exists public.leave_policy_decisions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  policy_profile_id uuid not null,
  environment_type text not null default 'production' check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  decision_type text not null,
  decision_title text not null,
  decision_note text not null,
  approved_by uuid not null references public.users(id) on delete restrict,
  approved_at timestamptz not null default now(),
  attachment_ref text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  constraint leave_policy_decisions_profile_scope_fkey
    foreign key (policy_profile_id, org_id, company_id, environment_type)
    references public.leave_policy_profiles(id, org_id, company_id, environment_type)
    on delete cascade
);

create index if not exists leave_policy_decisions_scope_idx
  on public.leave_policy_decisions (org_id, company_id, environment_type, approved_at desc);

-- -----------------------------------------------------------------------------
-- Baseline RLS
-- -----------------------------------------------------------------------------
alter table public.leave_policy_profiles enable row level security;
alter table public.leave_types enable row level security;
alter table public.leave_entitlement_rules enable row level security;
alter table public.holiday_calendar_sources enable row level security;
alter table public.holiday_calendar_days enable row level security;
alter table public.leave_compliance_warnings enable row level security;
alter table public.leave_policy_decisions enable row level security;

-- leave_policy_profiles
drop policy if exists leave_policy_profiles_select on public.leave_policy_profiles;
create policy leave_policy_profiles_select
on public.leave_policy_profiles
for select
using (leave_policy_can_read(org_id, company_id, environment_type));

drop policy if exists leave_policy_profiles_insert on public.leave_policy_profiles;
create policy leave_policy_profiles_insert
on public.leave_policy_profiles
for insert
with check (leave_policy_can_write(org_id, company_id, environment_type));

drop policy if exists leave_policy_profiles_update on public.leave_policy_profiles;
create policy leave_policy_profiles_update
on public.leave_policy_profiles
for update
using (leave_policy_can_write(org_id, company_id, environment_type))
with check (leave_policy_can_write(org_id, company_id, environment_type));

-- leave_types
drop policy if exists leave_types_select on public.leave_types;
create policy leave_types_select
on public.leave_types
for select
using (leave_policy_can_read(org_id, company_id, environment_type));

drop policy if exists leave_types_insert on public.leave_types;
create policy leave_types_insert
on public.leave_types
for insert
with check (leave_policy_can_write(org_id, company_id, environment_type));

drop policy if exists leave_types_update on public.leave_types;
create policy leave_types_update
on public.leave_types
for update
using (leave_policy_can_write(org_id, company_id, environment_type))
with check (leave_policy_can_write(org_id, company_id, environment_type));

-- leave_entitlement_rules
drop policy if exists leave_entitlement_rules_select on public.leave_entitlement_rules;
create policy leave_entitlement_rules_select
on public.leave_entitlement_rules
for select
using (leave_policy_can_read(org_id, company_id, environment_type));

drop policy if exists leave_entitlement_rules_insert on public.leave_entitlement_rules;
create policy leave_entitlement_rules_insert
on public.leave_entitlement_rules
for insert
with check (leave_policy_can_write(org_id, company_id, environment_type));

drop policy if exists leave_entitlement_rules_update on public.leave_entitlement_rules;
create policy leave_entitlement_rules_update
on public.leave_entitlement_rules
for update
using (leave_policy_can_write(org_id, company_id, environment_type))
with check (leave_policy_can_write(org_id, company_id, environment_type));

-- holiday_calendar_sources
drop policy if exists holiday_calendar_sources_select on public.holiday_calendar_sources;
create policy holiday_calendar_sources_select
on public.holiday_calendar_sources
for select
using (leave_policy_can_read(org_id, company_id, environment_type));

drop policy if exists holiday_calendar_sources_insert on public.holiday_calendar_sources;
create policy holiday_calendar_sources_insert
on public.holiday_calendar_sources
for insert
with check (leave_policy_can_write(org_id, company_id, environment_type));

drop policy if exists holiday_calendar_sources_update on public.holiday_calendar_sources;
create policy holiday_calendar_sources_update
on public.holiday_calendar_sources
for update
using (leave_policy_can_write(org_id, company_id, environment_type))
with check (leave_policy_can_write(org_id, company_id, environment_type));

-- holiday_calendar_days
drop policy if exists holiday_calendar_days_select on public.holiday_calendar_days;
create policy holiday_calendar_days_select
on public.holiday_calendar_days
for select
using (
  (
    org_id is null
    and company_id is null
    and leave_policy_can_read_global(environment_type)
  )
  or (
    org_id is not null
    and company_id is not null
    and leave_policy_can_read(org_id, company_id, environment_type)
  )
);

drop policy if exists holiday_calendar_days_insert on public.holiday_calendar_days;
create policy holiday_calendar_days_insert
on public.holiday_calendar_days
for insert
with check (
  org_id is not null
  and company_id is not null
  and leave_policy_can_write(org_id, company_id, environment_type)
);

drop policy if exists holiday_calendar_days_update on public.holiday_calendar_days;
create policy holiday_calendar_days_update
on public.holiday_calendar_days
for update
using (
  org_id is not null
  and company_id is not null
  and leave_policy_can_write(org_id, company_id, environment_type)
)
with check (
  org_id is not null
  and company_id is not null
  and leave_policy_can_write(org_id, company_id, environment_type)
);

-- leave_compliance_warnings
drop policy if exists leave_compliance_warnings_select on public.leave_compliance_warnings;
create policy leave_compliance_warnings_select
on public.leave_compliance_warnings
for select
using (leave_policy_can_read(org_id, company_id, environment_type));

drop policy if exists leave_compliance_warnings_insert on public.leave_compliance_warnings;
create policy leave_compliance_warnings_insert
on public.leave_compliance_warnings
for insert
with check (leave_policy_can_write(org_id, company_id, environment_type));

drop policy if exists leave_compliance_warnings_update on public.leave_compliance_warnings;
create policy leave_compliance_warnings_update
on public.leave_compliance_warnings
for update
using (leave_policy_can_write(org_id, company_id, environment_type))
with check (leave_policy_can_write(org_id, company_id, environment_type));

-- leave_policy_decisions
drop policy if exists leave_policy_decisions_select on public.leave_policy_decisions;
create policy leave_policy_decisions_select
on public.leave_policy_decisions
for select
using (leave_policy_can_read(org_id, company_id, environment_type));

drop policy if exists leave_policy_decisions_insert on public.leave_policy_decisions;
create policy leave_policy_decisions_insert
on public.leave_policy_decisions
for insert
with check (leave_policy_can_write(org_id, company_id, environment_type));

drop policy if exists leave_policy_decisions_update on public.leave_policy_decisions;
create policy leave_policy_decisions_update
on public.leave_policy_decisions
for update
using (leave_policy_can_write(org_id, company_id, environment_type))
with check (leave_policy_can_write(org_id, company_id, environment_type));

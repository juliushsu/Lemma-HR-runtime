-- CTO directive: Lemma HR Beta Lock Backend + Security Setup (STAGING ONLY)
-- Scope:
-- - sandbox test org bootstrap
-- - tester account binding to sandbox org
-- - helper functions: is_test_user / is_internal_user / is_sandbox_org
-- - API access logging table + helper
-- - RLS helper hardening for tester sandbox isolation
-- - production-mutation guardrails (staging lock)
-- - purge_test_data(org_id)

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- A) Minimal additive schema
-- ---------------------------------------------------------------------------
alter table if exists public.organizations
  add column if not exists slug text,
  add column if not exists is_test boolean not null default false;

create unique index if not exists organizations_slug_uidx
  on public.organizations (slug)
  where slug is not null;

alter table if exists public.companies
  add column if not exists is_test boolean not null default false;

alter table if exists public.branches
  add column if not exists is_test boolean not null default false;

alter table if exists public.users
  add column if not exists is_test boolean not null default false,
  add column if not exists is_internal boolean not null default false,
  add column if not exists security_role text not null default 'standard'
    check (security_role in ('standard', 'tester', 'internal'));

alter table if exists public.memberships
  add column if not exists is_test boolean not null default false;

alter table if exists public.employees
  add column if not exists is_test boolean not null default false;

alter table if exists public.company_settings
  add column if not exists is_test boolean not null default false;

alter table if exists public.attendance_boundary_settings
  add column if not exists is_test boolean not null default false;

create table if not exists public.api_access_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  endpoint text not null,
  timestamp timestamptz not null default now(),
  is_test_user boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists api_access_logs_user_time_idx
  on public.api_access_logs (user_id, timestamp desc);

create index if not exists api_access_logs_endpoint_time_idx
  on public.api_access_logs (endpoint, timestamp desc);

-- ---------------------------------------------------------------------------
-- B) Helper functions
-- ---------------------------------------------------------------------------
create or replace function public.is_sandbox_org(p_org_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.organizations o
    where o.id = p_org_id
      and o.environment_type = 'sandbox'
      and coalesce(o.is_test, false) = true
  );
$$;

create or replace function public.is_test_user(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.users u
    where u.id = p_user_id
      and (
        coalesce(u.is_test, false) = true
        or coalesce(u.security_role, 'standard') = 'tester'
      )
  );
$$;

create or replace function public.is_internal_user(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.users u
    where u.id = p_user_id
      and (
        coalesce(u.is_internal, false) = true
        or coalesce(u.security_role, 'standard') = 'internal'
        or lower(coalesce(u.email, '')) like '%@lemmaofficial.com'
      )
  );
$$;

create or replace function public.can_pass_beta_lock(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select public.is_test_user(p_user_id) or public.is_internal_user(p_user_id);
$$;

create or replace function public.log_api_access(
  p_endpoint text,
  p_is_test_user boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.api_access_logs (user_id, endpoint, is_test_user)
  values (auth.uid(), coalesce(p_endpoint, ''), coalesce(p_is_test_user, false));
end;
$$;

revoke all on function public.log_api_access(text, boolean) from public;
grant execute on function public.log_api_access(text, boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- C) Sandbox org + tester account bootstrap
-- ---------------------------------------------------------------------------
insert into public.organizations (
  id, slug, name, locale_default, environment_type, is_demo, is_test, created_by, updated_by
)
values (
  '10000000-0000-0000-0000-0000000000aa',
  'lemma-test-org',
  'Lemma Test Org',
  'en',
  'sandbox',
  false,
  true,
  null,
  null
)
on conflict (id) do update
set
  slug = excluded.slug,
  name = excluded.name,
  locale_default = excluded.locale_default,
  environment_type = excluded.environment_type,
  is_demo = excluded.is_demo,
  is_test = excluded.is_test,
  updated_at = now();

insert into public.companies (
  id, org_id, name, locale_default, environment_type, is_demo, is_test, created_by, updated_by
)
values (
  '20000000-0000-0000-0000-0000000000aa',
  '10000000-0000-0000-0000-0000000000aa',
  'Lemma Test Company',
  'en',
  'sandbox',
  false,
  true,
  null,
  null
)
on conflict (id) do update
set
  org_id = excluded.org_id,
  name = excluded.name,
  locale_default = excluded.locale_default,
  environment_type = excluded.environment_type,
  is_demo = excluded.is_demo,
  is_test = excluded.is_test,
  updated_at = now();

do $$
declare
  v_user_id uuid;
begin
  select au.id into v_user_id
  from auth.users au
  where lower(au.email) = 'team@lemmaofficial.com'
  order by au.created_at asc
  limit 1;

  if v_user_id is null then
    select u.id into v_user_id
    from public.users u
    where lower(u.email) = 'team@lemmaofficial.com'
    order by u.created_at asc
    limit 1;
  end if;

  if v_user_id is null then
    v_user_id := gen_random_uuid();
  end if;

  insert into public.users (
    id, email, display_name, locale_preference, timezone, currency, environment_type, is_demo, is_test, is_internal, security_role
  )
  values (
    v_user_id,
    'team@lemmaofficial.com',
    'Lemma Test Team',
    'en',
    'Asia/Taipei',
    'TWD',
    'sandbox',
    false,
    true,
    false,
    'tester'
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = excluded.display_name,
    locale_preference = excluded.locale_preference,
    timezone = excluded.timezone,
    currency = excluded.currency,
    environment_type = excluded.environment_type,
    is_demo = excluded.is_demo,
    is_test = excluded.is_test,
    is_internal = excluded.is_internal,
    security_role = excluded.security_role,
    updated_at = now();

  insert into public.memberships (
    id, user_id, org_id, company_id, branch_id, role, scope_type, environment_type, is_demo, is_test
  )
  values (
    gen_random_uuid(),
    v_user_id,
    '10000000-0000-0000-0000-0000000000aa',
    '20000000-0000-0000-0000-0000000000aa',
    null,
    'viewer',
    'company',
    'sandbox',
    false,
    true
  )
  on conflict do nothing;
end
$$;

-- ---------------------------------------------------------------------------
-- D) RLS helper hardening
-- ---------------------------------------------------------------------------
create or replace function public.can_access_row(row_org_id uuid, row_environment_type environment_type)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    join public.organizations o on o.id = m.org_id
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and o.environment_type = row_environment_type
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
  )
$$;

create or replace function public.can_read_scope(
  row_org_id uuid,
  row_company_id uuid,
  row_branch_id uuid,
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
      and m.role::text in ('owner','super_admin','admin','manager','operator','viewer')
      and (
        m.scope_type::text = 'org'
        or (m.scope_type::text = 'company' and m.company_id = row_company_id)
        or (m.scope_type::text = 'branch' and m.company_id = row_company_id and m.branch_id = row_branch_id)
        or m.scope_type::text = 'self'
      )
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
  )
$$;

create or replace function public.can_write_scope(
  row_org_id uuid,
  row_company_id uuid,
  row_branch_id uuid,
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
      and m.role::text in ('owner','super_admin','admin')
      and (
        m.scope_type::text = 'org'
        or (m.scope_type::text = 'company' and m.company_id = row_company_id)
        or (m.scope_type::text = 'branch' and m.company_id = row_company_id and m.branch_id = row_branch_id)
      )
      and public.is_sandbox_org(row_org_id)
  )
$$;

create or replace function public.legal_can_access_org(
  row_org_id uuid,
  row_environment_type environment_type
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
      and m.environment_type = row_environment_type
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
  )
$$;

create or replace function public.leave_can_company_read(
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
      and m.role::text in ('owner', 'super_admin', 'admin', 'manager')
      and m.scope_type::text in ('org', 'company')
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
  )
$$;

create or replace function public.leave_can_approve_scope(
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
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
  )
$$;

create or replace function public.onboarding_can_hr_read(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type environment_type
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
      and m.environment_type = row_environment_type
      and m.role::text in ('owner','admin','manager')
      and m.scope_type::text in ('org','company')
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
  )
$$;

create or replace function public.onboarding_can_hr_write(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type environment_type
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
      and m.environment_type = row_environment_type
      and m.role::text in ('owner','admin','manager')
      and m.scope_type::text in ('org','company')
      and public.is_sandbox_org(row_org_id)
  )
$$;

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
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
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
      and public.is_sandbox_org(row_org_id)
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
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(m.org_id)
      )
  )
$$;

-- ---------------------------------------------------------------------------
-- E) Staging write guard (is_test=false blocks writes for authenticated)
-- ---------------------------------------------------------------------------
create or replace function public.enforce_is_test_write()
returns trigger
language plpgsql
as $$
declare
  v_role text := coalesce(
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'role'), ''),
    ''
  );
begin
  -- keep service_role bootstrap and admin scripts unblocked
  if v_role = 'service_role' then
    return new;
  end if;

  if coalesce(new.is_test, false) = false then
    raise exception 'STAGING_WRITE_BLOCKED_NON_TEST_DATA';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_is_test_write_organizations on public.organizations;
create trigger trg_enforce_is_test_write_organizations
before insert or update on public.organizations
for each row execute function public.enforce_is_test_write();

drop trigger if exists trg_enforce_is_test_write_companies on public.companies;
create trigger trg_enforce_is_test_write_companies
before insert or update on public.companies
for each row execute function public.enforce_is_test_write();

drop trigger if exists trg_enforce_is_test_write_branches on public.branches;
create trigger trg_enforce_is_test_write_branches
before insert or update on public.branches
for each row execute function public.enforce_is_test_write();

drop trigger if exists trg_enforce_is_test_write_users on public.users;
create trigger trg_enforce_is_test_write_users
before insert or update on public.users
for each row execute function public.enforce_is_test_write();

drop trigger if exists trg_enforce_is_test_write_memberships on public.memberships;
create trigger trg_enforce_is_test_write_memberships
before insert or update on public.memberships
for each row execute function public.enforce_is_test_write();

drop trigger if exists trg_enforce_is_test_write_employees on public.employees;
create trigger trg_enforce_is_test_write_employees
before insert or update on public.employees
for each row execute function public.enforce_is_test_write();

drop trigger if exists trg_enforce_is_test_write_company_settings on public.company_settings;
create trigger trg_enforce_is_test_write_company_settings
before insert or update on public.company_settings
for each row execute function public.enforce_is_test_write();

drop trigger if exists trg_enforce_is_test_write_attendance_boundary_settings on public.attendance_boundary_settings;
create trigger trg_enforce_is_test_write_attendance_boundary_settings
before insert or update on public.attendance_boundary_settings
for each row execute function public.enforce_is_test_write();

-- ---------------------------------------------------------------------------
-- F) API access log policies
-- ---------------------------------------------------------------------------
alter table public.api_access_logs enable row level security;

drop policy if exists api_access_logs_self_read on public.api_access_logs;
create policy api_access_logs_self_read
on public.api_access_logs
for select
using (
  user_id = auth.uid()
  or public.is_internal_user(auth.uid())
);

drop policy if exists api_access_logs_insert_block on public.api_access_logs;
create policy api_access_logs_insert_block
on public.api_access_logs
for insert
with check (false);

-- ---------------------------------------------------------------------------
-- G) Purge helper (future use)
-- ---------------------------------------------------------------------------
create or replace function public.purge_test_data(p_org_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_ids uuid[];
  v_deleted_employees bigint := 0;
  v_deleted_attendance bigint := 0;
  v_deleted_leave bigint := 0;
begin
  if not public.is_sandbox_org(p_org_id) then
    raise exception 'PURGE_ALLOWED_ONLY_FOR_SANDBOX_TEST_ORG';
  end if;

  if not public.is_internal_user(auth.uid()) then
    raise exception 'INTERNAL_USER_REQUIRED_FOR_PURGE';
  end if;

  select array_agg(c.id) into v_company_ids
  from public.companies c
  where c.org_id = p_org_id;

  delete from public.attendance_adjustments a
  where a.org_id = p_org_id;

  delete from public.attendance_logs a
  where a.org_id = p_org_id;
  get diagnostics v_deleted_attendance = row_count;

  delete from public.leave_approval_logs l
  where l.org_id = p_org_id;

  delete from public.leave_request_attachments l
  where l.org_id = p_org_id;

  delete from public.leave_requests l
  where l.org_id = p_org_id;
  get diagnostics v_deleted_leave = row_count;

  delete from public.employee_language_skills s
  where s.org_id = p_org_id;

  delete from public.employees e
  where e.org_id = p_org_id;
  get diagnostics v_deleted_employees = row_count;

  return jsonb_build_object(
    'org_id', p_org_id,
    'deleted_counts', jsonb_build_object(
      'employees', v_deleted_employees,
      'attendance_logs', v_deleted_attendance,
      'leave_requests', v_deleted_leave
    )
  );
end;
$$;

revoke all on function public.purge_test_data(uuid) from public;
grant execute on function public.purge_test_data(uuid) to authenticated, service_role;

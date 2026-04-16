create extension if not exists pgcrypto;

-- 1) Core enums
create type environment_type as enum ('production', 'demo', 'sandbox', 'seed');
create type role_type as enum ('owner', 'super_admin', 'admin', 'manager', 'operator', 'viewer');
create type scope_type as enum ('org', 'company', 'branch', 'self');

-- 2) Core tables (no extension)
create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  locale_default text not null default 'en',
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create table companies (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  locale_default text not null default 'en',
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create table branches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  name text not null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create table users (
  id uuid primary key,
  email text unique,
  display_name text,
  locale_preference text not null default 'en',
  timezone text not null default 'UTC',
  currency text not null default 'USD',
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create table memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete cascade,
  role role_type not null,
  scope_type scope_type not null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create index memberships_user_idx on memberships(user_id);
create index memberships_org_idx on memberships(org_id);
create index memberships_company_idx on memberships(company_id);
create index branches_org_idx on branches(org_id);
create index companies_org_idx on companies(org_id);

-- 3) Minimal RLS helpers
create or replace function current_user_org_ids()
returns setof uuid
language sql
stable
as $$
  select m.org_id
  from memberships m
  where m.user_id = auth.uid()
$$;

create or replace function can_access_row(row_org_id uuid, row_environment_type environment_type)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from memberships m
    join organizations o on o.id = m.org_id
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and o.environment_type = row_environment_type
  )
$$;

-- 4) Enable RLS (minimal viable)
alter table organizations enable row level security;
alter table companies enable row level security;
alter table branches enable row level security;
alter table users enable row level security;
alter table memberships enable row level security;

-- user can only see their own org data
-- demo org data cannot be seen by production org users (environment matched via can_access_row)
create policy organizations_select_policy on organizations
for select
using (
  exists (
    select 1
    from memberships m
    where m.user_id = auth.uid()
      and m.org_id = organizations.id
      and can_access_row(organizations.id, organizations.environment_type)
  )
);

create policy companies_select_policy on companies
for select
using (can_access_row(companies.org_id, companies.environment_type));

create policy branches_select_policy on branches
for select
using (can_access_row(branches.org_id, branches.environment_type));

create policy memberships_select_policy on memberships
for select
using (can_access_row(memberships.org_id, memberships.environment_type));

create policy users_select_policy on users
for select
using (
  users.id = auth.uid()
  or exists (
    select 1
    from memberships m
    where m.user_id = users.id
      and can_access_row(m.org_id, users.environment_type)
  )
);

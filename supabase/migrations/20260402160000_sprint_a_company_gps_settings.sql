-- Sprint A: company + GPS settings skeleton (read-only foundation)
-- Scope:
-- 1) company_settings
-- 2) attendance_boundary_settings
-- 3) branches extension: latitude/longitude/is_attendance_enabled

create extension if not exists pgcrypto;

-- 1) branches extension
alter table if exists branches
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists is_attendance_enabled boolean not null default true;

alter table if exists branches
  drop constraint if exists branches_latitude_range_chk,
  add constraint branches_latitude_range_chk check (latitude is null or (latitude >= -90 and latitude <= 90)),
  drop constraint if exists branches_longitude_range_chk,
  add constraint branches_longitude_range_chk check (longitude is null or (longitude >= -180 and longitude <= 180));

-- 2) company_settings
create table if not exists company_settings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  company_legal_name text not null,
  tax_id text,
  address text,
  timezone text not null default 'Asia/Taipei',
  default_locale text not null default 'zh-TW',
  is_attendance_enabled boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, environment_type)
);

create index if not exists company_settings_scope_idx
on company_settings (org_id, company_id, environment_type);

-- 3) attendance_boundary_settings
create table if not exists attendance_boundary_settings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete cascade,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  checkin_radius_m int not null default 150 check (checkin_radius_m >= 10 and checkin_radius_m <= 5000),
  is_attendance_enabled boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create unique index if not exists attendance_boundary_company_default_uniq
on attendance_boundary_settings (org_id, company_id, environment_type)
where branch_id is null;

create unique index if not exists attendance_boundary_branch_uniq
on attendance_boundary_settings (org_id, company_id, branch_id, environment_type)
where branch_id is not null;

create index if not exists attendance_boundary_scope_idx
on attendance_boundary_settings (org_id, company_id, environment_type, branch_id);

-- RLS
alter table company_settings enable row level security;
alter table attendance_boundary_settings enable row level security;

drop policy if exists company_settings_select_policy on company_settings;
create policy company_settings_select_policy on company_settings
for select using (can_access_row(org_id, environment_type));

drop policy if exists company_settings_write_policy on company_settings;
create policy company_settings_write_policy on company_settings
for all using (can_access_row(org_id, environment_type))
with check (can_access_row(org_id, environment_type));

drop policy if exists attendance_boundary_settings_select_policy on attendance_boundary_settings;
create policy attendance_boundary_settings_select_policy on attendance_boundary_settings
for select using (can_access_row(org_id, environment_type));

drop policy if exists attendance_boundary_settings_write_policy on attendance_boundary_settings;
create policy attendance_boundary_settings_write_policy on attendance_boundary_settings
for all using (can_access_row(org_id, environment_type))
with check (can_access_row(org_id, environment_type));

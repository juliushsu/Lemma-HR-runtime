-- HR+ MVP v1 canonical schema
-- Scope: employee / org chart / attendance only
-- Excluded: leave, payroll, performance, ATS, workflow engine, document workflow,
-- advanced scheduling rules, labor-law engines

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- A. departments
-- -----------------------------------------------------------------------------
create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  department_code text not null,
  department_name text not null,
  parent_department_id uuid references departments(id) on delete set null,
  manager_employee_id uuid,
  sort_order int not null default 100,
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, department_code, environment_type)
);

-- -----------------------------------------------------------------------------
-- B. positions
-- -----------------------------------------------------------------------------
create table if not exists positions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  position_code text not null,
  position_name text not null,
  job_level text,
  is_managerial boolean not null default false,
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, position_code, environment_type)
);

-- -----------------------------------------------------------------------------
-- C. employees
-- -----------------------------------------------------------------------------
create table if not exists employees (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  employee_code text not null,
  legal_name text not null,
  preferred_name text,
  display_name text,

  work_email text,
  personal_email text,
  mobile_phone text,

  nationality_code text,
  work_country_code text,
  preferred_locale text,
  timezone text,

  department_id uuid,
  position_id uuid,
  manager_employee_id uuid,

  employment_type text not null check (employment_type in ('full_time','part_time','contractor','intern','temporary')),
  employment_status text not null check (employment_status in ('active','inactive','on_leave','terminated')),
  hire_date date,
  termination_date date,

  gender_note text,
  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, employee_code, environment_type)
);

-- FK constraints that depend on employees/departments/positions existing
alter table departments
  drop constraint if exists departments_manager_employee_id_fkey,
  add constraint departments_manager_employee_id_fkey
    foreign key (manager_employee_id) references employees(id) on delete set null;

alter table employees
  drop constraint if exists employees_department_id_fkey,
  add constraint employees_department_id_fkey
    foreign key (department_id) references departments(id) on delete set null,
  drop constraint if exists employees_position_id_fkey,
  add constraint employees_position_id_fkey
    foreign key (position_id) references positions(id) on delete set null,
  drop constraint if exists employees_manager_employee_id_fkey,
  add constraint employees_manager_employee_id_fkey
    foreign key (manager_employee_id) references employees(id) on delete set null;

-- -----------------------------------------------------------------------------
-- D. employee_assignments
-- -----------------------------------------------------------------------------
create table if not exists employee_assignments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  employee_id uuid not null references employees(id) on delete cascade,
  department_id uuid references departments(id) on delete set null,
  position_id uuid references positions(id) on delete set null,
  manager_employee_id uuid references employees(id) on delete set null,

  assignment_type text not null check (assignment_type in ('primary','secondary','temporary')),
  effective_from date not null,
  effective_to date,
  is_current boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create unique index if not exists employee_assignments_one_current_primary_idx
on employee_assignments (employee_id)
where is_current = true and assignment_type = 'primary';

-- -----------------------------------------------------------------------------
-- E. attendance_policies
-- -----------------------------------------------------------------------------
create table if not exists attendance_policies (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  policy_code text not null,
  policy_name text not null,
  timezone text not null,
  standard_check_in_time time,
  standard_check_out_time time,
  late_grace_minutes int not null default 0,
  early_leave_grace_minutes int not null default 0,
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, policy_code, environment_type)
);

-- -----------------------------------------------------------------------------
-- F. employee_attendance_profiles
-- -----------------------------------------------------------------------------
create table if not exists employee_attendance_profiles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  employee_id uuid not null references employees(id) on delete cascade,
  attendance_policy_id uuid not null references attendance_policies(id) on delete cascade,
  effective_from date not null,
  effective_to date,
  is_current boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create unique index if not exists employee_attendance_profiles_one_current_idx
on employee_attendance_profiles (employee_id)
where is_current = true;

-- -----------------------------------------------------------------------------
-- G. attendance_logs
-- -----------------------------------------------------------------------------
create table if not exists attendance_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  employee_id uuid not null references employees(id) on delete cascade,
  attendance_date date not null,
  check_type text not null check (check_type in ('check_in','check_out')),
  checked_at timestamptz not null,

  source_type text not null check (source_type in ('web','mobile','kiosk','line_liff','manual','import')),
  source_ref text,

  gps_lat numeric(10,7),
  gps_lng numeric(10,7),
  geo_distance_m numeric(10,2),
  is_within_geo_range boolean,

  status_code text not null check (status_code in ('normal','late','early_leave','missing','manual_adjusted','invalid')),
  is_valid boolean not null default true,
  is_adjusted boolean not null default false,

  note text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create index if not exists attendance_logs_org_company_employee_date_idx
on attendance_logs (org_id, company_id, employee_id, attendance_date);

create index if not exists attendance_logs_org_company_checked_at_idx
on attendance_logs (org_id, company_id, checked_at);

-- -----------------------------------------------------------------------------
-- H. attendance_adjustments
-- -----------------------------------------------------------------------------
create table if not exists attendance_adjustments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  attendance_log_id uuid not null references attendance_logs(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,

  adjustment_type text not null check (adjustment_type in ('time_correction','invalidate','note_update','status_override')),
  requested_value jsonb,
  original_value jsonb,
  reason text not null,

  approval_status text not null check (approval_status in ('pending','approved','rejected')),
  approved_by uuid references users(id) on delete set null,
  approved_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

-- -----------------------------------------------------------------------------
-- shared indexes
-- -----------------------------------------------------------------------------
create index if not exists departments_scope_idx on departments(org_id, company_id, branch_id);
create index if not exists positions_scope_idx on positions(org_id, company_id, branch_id);
create index if not exists employees_scope_idx on employees(org_id, company_id, branch_id);
create index if not exists employee_assignments_scope_idx on employee_assignments(org_id, company_id, branch_id);
create index if not exists attendance_policies_scope_idx on attendance_policies(org_id, company_id, branch_id);
create index if not exists employee_attendance_profiles_scope_idx on employee_attendance_profiles(org_id, company_id, branch_id);
create index if not exists attendance_adjustments_scope_idx on attendance_adjustments(org_id, company_id, branch_id);

-- -----------------------------------------------------------------------------
-- Minimal RLS + scope helpers
-- -----------------------------------------------------------------------------
create or replace function current_jwt_employee_id()
returns uuid
language sql
stable
as $$
  select nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'employee_id'), '')::uuid
$$;

create or replace function can_read_scope(
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
    from memberships m
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
  )
$$;

create or replace function can_write_scope(
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
    from memberships m
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
  )
$$;

alter table departments enable row level security;
alter table positions enable row level security;
alter table employees enable row level security;
alter table employee_assignments enable row level security;
alter table attendance_policies enable row level security;
alter table employee_attendance_profiles enable row level security;
alter table attendance_logs enable row level security;
alter table attendance_adjustments enable row level security;

-- org chart + employee domain
create policy departments_select_policy on departments
for select using (can_read_scope(org_id, company_id, branch_id, environment_type));

create policy departments_write_policy on departments
for all using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

create policy positions_select_policy on positions
for select using (can_read_scope(org_id, company_id, branch_id, environment_type));

create policy positions_write_policy on positions
for all using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

create policy employees_select_policy on employees
for select using (can_read_scope(org_id, company_id, branch_id, environment_type));

create policy employees_write_policy on employees
for all using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

create policy employee_assignments_select_policy on employee_assignments
for select using (can_read_scope(org_id, company_id, branch_id, environment_type));

create policy employee_assignments_write_policy on employee_assignments
for all using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

-- attendance domain
create policy attendance_policies_select_policy on attendance_policies
for select using (can_read_scope(org_id, company_id, branch_id, environment_type));

create policy attendance_policies_write_policy on attendance_policies
for all using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

create policy employee_attendance_profiles_select_policy on employee_attendance_profiles
for select using (can_read_scope(org_id, company_id, branch_id, environment_type));

create policy employee_attendance_profiles_write_policy on employee_attendance_profiles
for all using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

create policy attendance_logs_select_policy on attendance_logs
for select using (
  can_read_scope(org_id, company_id, branch_id, environment_type)
  or employee_id = current_jwt_employee_id()
);

create policy attendance_logs_insert_policy on attendance_logs
for insert with check (
  can_write_scope(org_id, company_id, branch_id, environment_type)
  or employee_id = current_jwt_employee_id()
);

create policy attendance_logs_update_policy on attendance_logs
for update using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

create policy attendance_adjustments_select_policy on attendance_adjustments
for select using (
  can_read_scope(org_id, company_id, branch_id, environment_type)
  or employee_id = current_jwt_employee_id()
);

create policy attendance_adjustments_write_policy on attendance_adjustments
for all using (can_write_scope(org_id, company_id, branch_id, environment_type))
with check (can_write_scope(org_id, company_id, branch_id, environment_type));

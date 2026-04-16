-- Sprint 2B.6.2 - Manual Upload backend MVP (CSV/XLSX only)
-- Scope: import batch + parsed rows + confirm import to attendance_logs

create table if not exists attendance_import_batches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  source_type text not null default 'manual_upload' check (source_type = 'manual_upload'),
  file_name text not null,
  file_type text not null check (file_type in ('csv','xlsx')),

  status text not null default 'preview_ready'
    check (status in ('preview_ready','importing','imported','partially_imported','failed','cancelled')),

  total_rows integer not null default 0,
  valid_rows integer not null default 0,
  invalid_rows integer not null default 0,
  duplicate_rows integer not null default 0,
  imported_rows integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create index if not exists attendance_import_batches_scope_idx
on attendance_import_batches (org_id, company_id, environment_type, created_at desc);

create table if not exists attendance_import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references attendance_import_batches(id) on delete cascade,
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  row_index integer not null,
  employee_code text,
  attendance_date date,
  check_type text check (check_type in ('check_in','check_out')),
  checked_at timestamptz,

  parsed_payload jsonb not null default '{}'::jsonb,
  corrected_payload jsonb,

  status text not null default 'pending'
    check (status in ('valid','error','imported','rejected')),
  error_code text,
  error_message text,
  is_duplicate boolean not null default false,
  is_corrected boolean not null default false,
  review_note text,
  reviewed_by uuid,
  reviewed_at timestamptz,

  imported_attendance_log_id uuid references attendance_logs(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique(batch_id, row_index)
);

create index if not exists attendance_import_rows_batch_idx
on attendance_import_rows (batch_id, status, row_index);

create index if not exists attendance_import_rows_scope_idx
on attendance_import_rows (org_id, company_id, environment_type, created_at desc);

alter table attendance_import_batches enable row level security;
alter table attendance_import_rows enable row level security;

-- Keep direct client access denied by default.

alter table attendance_logs
  drop constraint if exists attendance_logs_source_type_check,
  add constraint attendance_logs_source_type_check
    check (source_type in ('web','mobile','kiosk','line_liff','line','manual','import','manual_upload'));

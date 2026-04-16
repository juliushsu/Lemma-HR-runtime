-- Sprint 2B.8 - External API Import backend MVP
-- Scope: source registration/config + inbound preview + confirm import + audit history

create table if not exists attendance_source_registry (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  source_type text not null check (source_type in ('external_api')),
  source_key text not null,
  source_name text not null,
  auth_mode text not null check (auth_mode in ('hmac_sha256', 'bearer_token')),
  credential text not null,
  config_json jsonb not null default '{}'::jsonb,
  is_enabled boolean not null default true,
  last_validated_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create unique index if not exists attendance_source_registry_scope_key_uidx
on attendance_source_registry (org_id, company_id, environment_type, source_type, source_key);

create index if not exists attendance_source_registry_scope_idx
on attendance_source_registry (org_id, company_id, environment_type, is_enabled, created_at desc);

create table if not exists attendance_external_event_audits (
  id uuid primary key default gen_random_uuid(),
  source_registry_id uuid not null references attendance_source_registry(id) on delete cascade,
  batch_id uuid references attendance_import_batches(id) on delete set null,
  row_id uuid references attendance_import_rows(id) on delete set null,

  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  event_id text,
  source_ref text,
  dedupe_key text,
  event_type text not null default 'attendance',
  result_status text not null
    check (result_status in ('received', 'preview_valid', 'preview_error', 'imported', 'failed', 'rejected', 'duplicate')),
  failure_code text,
  failure_reason text,
  payload jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid
);

create unique index if not exists attendance_external_event_audits_event_uidx
on attendance_external_event_audits (source_registry_id, event_id)
where event_id is not null and event_id <> '';

create unique index if not exists attendance_external_event_audits_source_ref_uidx
on attendance_external_event_audits (source_registry_id, source_ref)
where source_ref is not null and source_ref <> '';

create index if not exists attendance_external_event_audits_scope_idx
on attendance_external_event_audits (org_id, company_id, environment_type, created_at desc);

alter table attendance_import_batches
  add column if not exists source_registry_id uuid references attendance_source_registry(id) on delete set null,
  add column if not exists sync_mode text not null default 'inbound'
    check (sync_mode in ('inbound'));

alter table attendance_import_batches
  drop constraint if exists attendance_import_batches_source_type_check,
  add constraint attendance_import_batches_source_type_check
    check (source_type in ('manual_upload', 'external_api'));

alter table attendance_import_batches
  drop constraint if exists attendance_import_batches_file_type_check,
  add constraint attendance_import_batches_file_type_check
    check (file_type in ('csv', 'xlsx', 'json'));

alter table attendance_import_rows
  add column if not exists external_employee_ref text,
  add column if not exists event_id text,
  add column if not exists source_ref text;

create index if not exists attendance_import_rows_batch_event_idx
on attendance_import_rows (batch_id, event_id, source_ref);

alter table attendance_source_registry enable row level security;
alter table attendance_external_event_audits enable row level security;

alter table attendance_logs
  drop constraint if exists attendance_logs_source_type_check,
  add constraint attendance_logs_source_type_check
    check (source_type in ('web', 'mobile', 'kiosk', 'line_liff', 'line', 'manual', 'import', 'manual_upload', 'external_api'));

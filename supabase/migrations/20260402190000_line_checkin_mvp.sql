-- Sprint 2B.2 LINE check-in MVP
-- Scope: binding token + line binding + webhook event audit + attendance source_type=line support

create extension if not exists pgcrypto;

create table if not exists line_binding_tokens (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  employee_id uuid not null references employees(id) on delete cascade,
  user_id uuid references users(id) on delete set null,

  token_hash text not null unique,
  token_last4 text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  status text not null default 'pending' check (status in ('pending','consumed','expired','revoked')),

  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create index if not exists line_binding_tokens_scope_idx
on line_binding_tokens (org_id, company_id, environment_type, employee_id, status, expires_at);

create table if not exists line_bindings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type text not null check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean not null default false,

  line_user_id text not null,
  line_display_name text,
  user_id uuid references users(id) on delete set null,
  employee_id uuid not null references employees(id) on delete cascade,

  bind_status text not null default 'active' check (bind_status in ('active','revoked')),
  bound_at timestamptz not null default now(),
  revoked_at timestamptz,
  last_seen_at timestamptz,

  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create unique index if not exists line_bindings_line_user_env_uniq
on line_bindings (line_user_id, environment_type);

create index if not exists line_bindings_scope_idx
on line_bindings (org_id, company_id, environment_type, employee_id, bind_status);

create table if not exists line_webhook_event_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references organizations(id) on delete set null,
  company_id uuid references companies(id) on delete set null,
  branch_id uuid references branches(id) on delete set null,
  environment_type text check (environment_type in ('production','demo','sandbox','seed')),
  is_demo boolean,

  line_user_id text,
  event_id text,
  event_type text not null default 'attendance.check',
  source_ref text,
  request_payload jsonb not null default '{}'::jsonb,
  decision_code text,
  decision_message text,
  attendance_log_id uuid references attendance_logs(id) on delete set null,

  created_at timestamptz not null default now()
);

create unique index if not exists line_webhook_event_logs_event_id_uniq
on line_webhook_event_logs (event_id)
where event_id is not null;

create index if not exists line_webhook_event_logs_scope_idx
on line_webhook_event_logs (org_id, company_id, environment_type, created_at desc);

alter table line_binding_tokens enable row level security;
alter table line_bindings enable row level security;
alter table line_webhook_event_logs enable row level security;

-- Keep client-side direct access denied by default.

alter table attendance_logs
  drop constraint if exists attendance_logs_source_type_check,
  add constraint attendance_logs_source_type_check
    check (source_type in ('web','mobile','kiosk','line_liff','line','manual','import'));


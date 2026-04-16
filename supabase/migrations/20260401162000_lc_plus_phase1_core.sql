-- LC+ Phase 1 core
-- Includes only:
-- 1) legal_documents
-- 2) legal_document_versions
-- 3) legal_document_tags
-- 4) legal_cases
-- 5) legal_case_documents
-- Excludes:
-- - legal_ai_analyses
-- - legal_credit_ledgers
-- - NLP/OCR/AI logic

create extension if not exists pgcrypto;

create table if not exists legal_documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  document_code text not null,
  title text not null,
  document_type text not null check (
    document_type in (
      'employment_contract',
      'procurement_contract',
      'sales_contract',
      'nda',
      'policy',
      'memo',
      'other'
    )
  ),
  governing_law_code text,
  jurisdiction_note text,
  counterparty_name text,
  counterparty_type text,
  effective_date date,
  expiry_date date,
  auto_renewal_date date,
  signing_status text not null default 'draft',
  current_version_id uuid,
  source_module text check (source_module in ('hr_plus', 'po_plus', 'so_plus', 'acc_plus', 'lc_plus')),
  source_record_id uuid,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, document_code, environment_type)
);

create table if not exists legal_document_versions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  legal_document_id uuid not null references legal_documents(id) on delete cascade,
  version_no int not null,
  storage_path text not null,
  file_name text not null,
  file_ext text,
  mime_type text,
  file_size_bytes bigint,
  checksum text,
  uploaded_by uuid,
  uploaded_at timestamptz not null default now(),
  is_current boolean not null default false,
  parsed_status text not null default 'pending',
  parsing_error text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (legal_document_id, version_no)
);

create unique index if not exists legal_document_versions_one_current_idx
on legal_document_versions (legal_document_id)
where is_current = true;

alter table legal_documents
  drop constraint if exists legal_documents_current_version_id_fkey,
  add constraint legal_documents_current_version_id_fkey
  foreign key (current_version_id) references legal_document_versions(id) on delete set null;

create table if not exists legal_document_tags (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  legal_document_id uuid not null references legal_documents(id) on delete cascade,
  tag text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (legal_document_id, tag)
);

create table if not exists legal_cases (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  case_code text not null,
  case_type text not null check (
    case_type in (
      'labor_dispute',
      'contract_breach',
      'payment_dispute',
      'procurement_dispute',
      'ip_dispute',
      'other'
    )
  ),
  title text not null,
  status text not null default 'open' check (
    status in ('open', 'under_review', 'strategy_prepared', 'external_counsel', 'closed')
  ),
  governing_law_code text,
  forum_note text,
  risk_level text,
  summary text,
  owner_user_id uuid references users(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, case_code, environment_type)
);

create table if not exists legal_case_documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  legal_case_id uuid not null references legal_cases(id) on delete cascade,
  legal_document_id uuid not null references legal_documents(id) on delete cascade,
  relationship_type text not null default 'evidence',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (legal_case_id, legal_document_id)
);

create index if not exists legal_documents_scope_idx
  on legal_documents(org_id, company_id, branch_id, environment_type);
create index if not exists legal_document_versions_scope_idx
  on legal_document_versions(org_id, company_id, branch_id, environment_type);
create index if not exists legal_document_tags_scope_idx
  on legal_document_tags(org_id, company_id, branch_id, environment_type);
create index if not exists legal_cases_scope_idx
  on legal_cases(org_id, company_id, branch_id, environment_type);
create index if not exists legal_case_documents_scope_idx
  on legal_case_documents(org_id, company_id, branch_id, environment_type);

-- Minimal org-scope RLS (with environment isolation)
create or replace function legal_can_access_org(
  row_org_id uuid,
  row_environment_type environment_type
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
      and m.environment_type = row_environment_type
  )
$$;

alter table legal_documents enable row level security;
alter table legal_document_versions enable row level security;
alter table legal_document_tags enable row level security;
alter table legal_cases enable row level security;
alter table legal_case_documents enable row level security;

create policy legal_documents_select_policy on legal_documents
for select using (legal_can_access_org(org_id, environment_type));
create policy legal_documents_write_policy on legal_documents
for all using (legal_can_access_org(org_id, environment_type))
with check (legal_can_access_org(org_id, environment_type));

create policy legal_document_versions_select_policy on legal_document_versions
for select using (legal_can_access_org(org_id, environment_type));
create policy legal_document_versions_write_policy on legal_document_versions
for all using (legal_can_access_org(org_id, environment_type))
with check (legal_can_access_org(org_id, environment_type));

create policy legal_document_tags_select_policy on legal_document_tags
for select using (legal_can_access_org(org_id, environment_type));
create policy legal_document_tags_write_policy on legal_document_tags
for all using (legal_can_access_org(org_id, environment_type))
with check (legal_can_access_org(org_id, environment_type));

create policy legal_cases_select_policy on legal_cases
for select using (legal_can_access_org(org_id, environment_type));
create policy legal_cases_write_policy on legal_cases
for all using (legal_can_access_org(org_id, environment_type))
with check (legal_can_access_org(org_id, environment_type));

create policy legal_case_documents_select_policy on legal_case_documents
for select using (legal_can_access_org(org_id, environment_type));
create policy legal_case_documents_write_policy on legal_case_documents
for all using (legal_can_access_org(org_id, environment_type))
with check (legal_can_access_org(org_id, environment_type));


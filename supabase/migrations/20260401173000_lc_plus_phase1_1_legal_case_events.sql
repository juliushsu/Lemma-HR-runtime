-- LC+ Phase 1.1 Incremental Patch
-- Add only legal_case_events (compatible with existing Phase 1 schema/routes).
-- Do not modify existing legal_documents/legal_document_versions/legal_document_tags/legal_cases/legal_case_documents.

create extension if not exists pgcrypto;

create table if not exists public.legal_case_events (
  id uuid primary key default gen_random_uuid(),

  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  legal_case_id uuid not null references public.legal_cases(id) on delete cascade,
  event_date date not null,
  event_type text not null,
  description text not null,
  source_document_id uuid references public.legal_documents(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create index if not exists legal_case_events_scope_idx
  on public.legal_case_events(org_id, company_id, branch_id, environment_type);

create index if not exists legal_case_events_case_date_idx
  on public.legal_case_events(legal_case_id, event_date);

alter table public.legal_case_events enable row level security;

drop policy if exists legal_case_events_select_policy on public.legal_case_events;
create policy legal_case_events_select_policy on public.legal_case_events
for select using (legal_can_access_org(org_id, environment_type));

drop policy if exists legal_case_events_write_policy on public.legal_case_events;
create policy legal_case_events_write_policy on public.legal_case_events
for all using (legal_can_access_org(org_id, environment_type))
with check (legal_can_access_org(org_id, environment_type));


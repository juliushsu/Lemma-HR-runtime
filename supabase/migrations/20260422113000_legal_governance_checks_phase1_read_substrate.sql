-- Legal governance checks Phase 1 read substrate
-- Purpose:
-- - establish the minimal canonical DB substrate for Railway-owned governance reads
-- - support GET /api/legal/governance-checks and GET /api/legal/governance-checks/:id
-- - keep JSON comparison payloads intact in Phase 1 instead of over-normalizing too early

create table if not exists public.legal_governance_checks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete set null,
  environment_type public.environment_type not null default 'production',
  is_demo boolean not null default false,

  domain text not null check (domain in ('leave', 'attendance', 'payroll', 'contract', 'insurance')),
  check_type text not null,
  target_object_type text not null,
  target_object_id text not null,
  jurisdiction_code text not null,
  rule_strength text not null check (rule_strength in ('mandatory_minimum', 'recommended_best_practice', 'company_discretion')),
  title text not null,
  statutory_minimum_json jsonb not null default '{}'::jsonb,
  company_current_value_json jsonb not null default '{}'::jsonb,
  ai_suggested_value_json jsonb not null default '{}'::jsonb,
  deviation_type text not null,
  severity text not null check (severity in ('info', 'low', 'medium', 'high', 'critical')),
  company_decision_status text not null check (company_decision_status in ('pending_review', 'adopted', 'kept_current', 'acknowledged_risk')),
  impact_domain text not null check (impact_domain in ('leave', 'attendance', 'payroll', 'contract', 'insurance')),
  reason_summary text not null,
  source_ref_json jsonb not null default '{}'::jsonb,
  created_by_source text not null check (created_by_source in ('ai_scan', 'manual_trigger', 'scheduled_job')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint legal_governance_checks_statutory_minimum_json_object
    check (jsonb_typeof(statutory_minimum_json) = 'object'),
  constraint legal_governance_checks_company_current_value_json_object
    check (jsonb_typeof(company_current_value_json) = 'object'),
  constraint legal_governance_checks_ai_suggested_value_json_object
    check (jsonb_typeof(ai_suggested_value_json) = 'object'),
  constraint legal_governance_checks_source_ref_json_object
    check (jsonb_typeof(source_ref_json) = 'object')
);

comment on table public.legal_governance_checks is
  'Phase 1 governance read substrate for Railway canonical governance comparison routes.';

create index if not exists legal_governance_checks_scope_idx
  on public.legal_governance_checks (org_id, company_id, branch_id, environment_type);

create index if not exists legal_governance_checks_domain_idx
  on public.legal_governance_checks (domain, jurisdiction_code, environment_type);

create index if not exists legal_governance_checks_status_idx
  on public.legal_governance_checks (company_decision_status, updated_at desc);

create index if not exists legal_governance_checks_severity_idx
  on public.legal_governance_checks (severity, updated_at desc);

create index if not exists legal_governance_checks_target_idx
  on public.legal_governance_checks (target_object_type, target_object_id);

drop trigger if exists trg_legal_governance_checks_updated_at on public.legal_governance_checks;
create trigger trg_legal_governance_checks_updated_at
before update on public.legal_governance_checks
for each row execute function public.set_updated_at();

alter table public.legal_governance_checks enable row level security;

drop policy if exists legal_governance_checks_select_policy on public.legal_governance_checks;
create policy legal_governance_checks_select_policy on public.legal_governance_checks
for select using (public.legal_can_access_org(org_id, environment_type));

drop policy if exists legal_governance_checks_write_policy on public.legal_governance_checks;
create policy legal_governance_checks_write_policy on public.legal_governance_checks
for all using (public.legal_can_access_org(org_id, environment_type))
with check (public.legal_can_access_org(org_id, environment_type));

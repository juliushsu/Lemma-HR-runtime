-- Legal governance acknowledge-warning mutation substrate
-- Purpose:
-- - add an append-only governance decision ledger
-- - keep company policy unchanged while recording human risk acceptance
-- - execute scope check, decision insert, and check status transition in one DB function

create extension if not exists pgcrypto;

create table if not exists public.legal_governance_decisions (
  id uuid primary key default gen_random_uuid(),
  check_id uuid not null references public.legal_governance_checks(id) on delete restrict,
  decision_type text not null check (decision_type in ('acknowledge_warning')),
  actor_user_id uuid not null references public.users(id) on delete restrict,
  reason text,
  acknowledged_at timestamptz not null,
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  environment_type public.environment_type not null,
  created_at timestamptz not null default now()
);

comment on table public.legal_governance_decisions is
  'Append-only governance decision ledger for legal governance checks.';

create index if not exists legal_governance_decisions_check_ack_idx
  on public.legal_governance_decisions (check_id, acknowledged_at desc);

create index if not exists legal_governance_decisions_scope_created_idx
  on public.legal_governance_decisions (org_id, company_id, environment_type, created_at desc);

alter table public.legal_governance_decisions enable row level security;

drop policy if exists legal_governance_decisions_select_policy on public.legal_governance_decisions;
create policy legal_governance_decisions_select_policy on public.legal_governance_decisions
for select using (public.legal_can_access_org(org_id, environment_type));

drop policy if exists legal_governance_decisions_insert_policy on public.legal_governance_decisions;
create policy legal_governance_decisions_insert_policy on public.legal_governance_decisions
for insert with check (public.legal_can_access_org(org_id, environment_type));

create or replace function public.prevent_legal_governance_decisions_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'LEGAL_GOVERNANCE_DECISIONS_APPEND_ONLY';
end;
$$;

drop trigger if exists trg_legal_governance_decisions_no_update on public.legal_governance_decisions;
create trigger trg_legal_governance_decisions_no_update
before update on public.legal_governance_decisions
for each row execute function public.prevent_legal_governance_decisions_mutation();

drop trigger if exists trg_legal_governance_decisions_no_delete on public.legal_governance_decisions;
create trigger trg_legal_governance_decisions_no_delete
before delete on public.legal_governance_decisions
for each row execute function public.prevent_legal_governance_decisions_mutation();

create or replace function public.acknowledge_governance_warning(
  p_payload jsonb
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_check_id uuid := nullif(trim(coalesce(p_payload ->> 'check_id', '')), '')::uuid;
  v_actor_user_id uuid := coalesce(auth.uid(), nullif(trim(coalesce(p_payload ->> 'actor_user_id', '')), '')::uuid);
  v_org_id uuid := nullif(trim(coalesce(p_payload ->> 'org_id', '')), '')::uuid;
  v_company_id uuid := nullif(trim(coalesce(p_payload ->> 'company_id', '')), '')::uuid;
  v_branch_id uuid := nullif(trim(coalesce(p_payload ->> 'branch_id', '')), '')::uuid;
  v_environment_type public.environment_type := nullif(trim(coalesce(p_payload ->> 'environment_type', '')), '')::public.environment_type;
  v_reason text := nullif(trim(coalesce(p_payload ->> 'reason', '')), '');
  v_check public.legal_governance_checks%rowtype;
  v_existing_decision public.legal_governance_decisions%rowtype;
  v_decision public.legal_governance_decisions%rowtype;
  v_acknowledged_at timestamptz := now();
begin
  if v_check_id is null or v_actor_user_id is null or v_org_id is null or v_company_id is null or v_environment_type is null then
    raise exception 'INVALID_REQUEST';
  end if;

  if auth.uid() is not null and v_actor_user_id <> auth.uid() then
    raise exception 'INVALID_REQUEST';
  end if;

  select *
    into v_check
  from public.legal_governance_checks lgc
  where lgc.id = v_check_id
  for update;

  if not found then
    raise exception 'CHECK_NOT_FOUND';
  end if;

  if v_check.org_id <> v_org_id
     or v_check.company_id <> v_company_id
     or v_check.environment_type <> v_environment_type
     or (v_branch_id is not null and v_check.branch_id is not null and v_check.branch_id <> v_branch_id) then
    raise exception 'SCOPE_FORBIDDEN';
  end if;

  if v_check.company_decision_status = 'acknowledged_risk' then
    select *
      into v_existing_decision
    from public.legal_governance_decisions lgd
    where lgd.check_id = v_check.id
      and lgd.decision_type = 'acknowledge_warning'
    order by lgd.acknowledged_at desc, lgd.created_at desc
    limit 1;

    return jsonb_build_object(
      'check_id', v_check.id,
      'company_decision_status', v_check.company_decision_status,
      'check', jsonb_build_object(
        'id', v_check.id,
        'company_decision_status', v_check.company_decision_status,
        'rule_strength', v_check.rule_strength,
        'severity', v_check.severity,
        'impact_domain', v_check.impact_domain,
        'updated_at', v_check.updated_at
      ),
      'decision', jsonb_build_object(
        'type', 'acknowledge_warning',
        'actor_user_id', coalesce(v_existing_decision.actor_user_id, v_actor_user_id),
        'acknowledged_at', coalesce(v_existing_decision.acknowledged_at, v_check.updated_at, v_acknowledged_at),
        'idempotent', true
      )
    );
  end if;

  if v_check.company_decision_status <> 'pending_review' then
    raise exception 'REQUEST_ALREADY_RESOLVED';
  end if;

  insert into public.legal_governance_decisions (
    check_id,
    decision_type,
    actor_user_id,
    reason,
    acknowledged_at,
    org_id,
    company_id,
    environment_type
  )
  values (
    v_check.id,
    'acknowledge_warning',
    v_actor_user_id,
    v_reason,
    v_acknowledged_at,
    v_check.org_id,
    v_check.company_id,
    v_check.environment_type
  )
  returning * into v_decision;

  update public.legal_governance_checks lgc
  set company_decision_status = 'acknowledged_risk'
  where lgc.id = v_check.id;

  select *
    into v_check
  from public.legal_governance_checks lgc
  where lgc.id = v_check.id;

  return jsonb_build_object(
    'check_id', v_check.id,
    'company_decision_status', 'acknowledged_risk',
    'check', jsonb_build_object(
      'id', v_check.id,
      'company_decision_status', v_check.company_decision_status,
      'rule_strength', v_check.rule_strength,
      'severity', v_check.severity,
      'impact_domain', v_check.impact_domain,
      'updated_at', v_check.updated_at
    ),
    'decision', jsonb_build_object(
      'type', 'acknowledge_warning',
      'actor_user_id', v_decision.actor_user_id,
      'acknowledged_at', v_decision.acknowledged_at
    )
  );
end;
$$;

comment on function public.acknowledge_governance_warning(jsonb) is
  'Phase 1 governance decision writer for acknowledge-warning. Records a human risk acceptance decision without mutating company policy.';

revoke all on function public.acknowledge_governance_warning(jsonb) from public;
grant execute on function public.acknowledge_governance_warning(jsonb) to service_role;

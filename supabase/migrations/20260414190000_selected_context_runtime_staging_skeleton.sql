-- STAGING ONLY SKELETON
-- Selected context runtime convergence for staging-first rollout.
-- This migration is intentionally designed as a safe skeleton:
-- - adds organization access_mode for policy clarity
-- - prepares helper functions for future RLS convergence
-- - keeps demo contexts read-only even for admin roles
-- - does not enable production rollout

alter table if exists public.organizations
  add column if not exists access_mode text;

alter table if exists public.organizations
  drop constraint if exists organizations_access_mode_check;

alter table if exists public.organizations
  add constraint organizations_access_mode_check
  check (access_mode in ('read_only_demo', 'sandbox_write', 'production_live') or access_mode is null);

update public.organizations
set access_mode = case
  when is_demo = true or environment_type::text = 'demo' then 'read_only_demo'
  when environment_type::text in ('sandbox', 'seed') then 'sandbox_write'
  else 'production_live'
end
where access_mode is null;

create or replace function public.current_membership_id()
returns uuid
language plpgsql
stable
as $$
declare
  v_claims jsonb;
  v_membership_id text;
begin
  begin
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  exception when others then
    v_claims := null;
  end;

  v_membership_id := coalesce(
    v_claims #>> '{app_metadata,selected_membership_id}',
    v_claims ->> 'selected_membership_id'
  );

  if v_membership_id is null or btrim(v_membership_id) = '' then
    return null;
  end if;

  return v_membership_id::uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.current_org_id()
returns uuid
language sql
stable
as $$
  select m.org_id
  from public.memberships m
  where m.id = public.current_membership_id()
    and m.user_id = auth.uid()
  limit 1
$$;

create or replace function public.current_access_mode()
returns text
language sql
stable
as $$
  select coalesce(
    o.access_mode,
    case
      when m.is_demo = true or m.environment_type::text = 'demo' then 'read_only_demo'
      when m.environment_type::text in ('sandbox', 'seed') then 'sandbox_write'
      else 'production_live'
    end
  )
  from public.memberships m
  join public.organizations o on o.id = m.org_id
  where m.id = public.current_membership_id()
    and m.user_id = auth.uid()
  limit 1
$$;

create or replace function public.can_write_scope(
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
    from public.memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (row_company_id is null or m.company_id is null or m.company_id = row_company_id)
      and m.environment_type::text = row_environment_type
      and m.role::text in ('owner','super_admin','admin')
      and (
        m.scope_type::text = 'org'
        or (m.scope_type::text = 'company' and (row_company_id is null or m.company_id = row_company_id))
        or (m.scope_type::text = 'branch' and row_company_id is not null and m.company_id = row_company_id and m.branch_id = row_branch_id)
      )
      and coalesce(public.current_access_mode(), 'production_live') <> 'read_only_demo'
      and (
        public.current_membership_id() is null
        or m.id = public.current_membership_id()
      )
      and (
        not public.is_test_user(auth.uid())
        or row_environment_type = 'sandbox'
      )
  )
$$;

-- Rollout note:
-- app-layer runtime in staging uses a server-owned HttpOnly cookie to persist selected membership.
-- future database-layer convergence may mirror selected_membership_id into request.jwt.claims
-- or another trusted request-scoped server-injected mechanism before enabling these helpers as canonical.

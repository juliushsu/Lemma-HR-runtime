-- STAGING ONLY: fix RLS helper recursion for organizations/companies lookups
-- Root cause: can_access_row/can_read_scope/can_write_scope referenced organizations via is_sandbox_org()
-- which recursively re-triggered organizations RLS and caused stack depth errors.

create or replace function public.can_access_row(row_org_id uuid, row_environment_type environment_type)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and m.environment_type = row_environment_type
      and (
        not public.is_test_user(auth.uid())
        or row_environment_type::text = 'sandbox'
      )
  )
$$;

create or replace function public.can_read_scope(
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
      and m.role::text in ('owner','super_admin','admin','manager','operator','viewer','portal_user')
      and (
        m.scope_type::text = 'org'
        or (m.scope_type::text = 'company' and (row_company_id is null or m.company_id = row_company_id))
        or (m.scope_type::text = 'branch' and row_company_id is not null and m.company_id = row_company_id and m.branch_id = row_branch_id)
        or m.scope_type::text = 'self'
      )
      and (
        not public.is_test_user(auth.uid())
        or row_environment_type = 'sandbox'
      )
  )
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
      and (
        not public.is_test_user(auth.uid())
        or row_environment_type = 'sandbox'
      )
  )
$$;

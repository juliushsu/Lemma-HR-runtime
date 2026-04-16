-- Lemma HR Client Portal Data Layer (STAGING)
-- Scope:
-- - additive role + helper for portal read access
-- - keep read-only portal behavior
-- - patch can_read_scope to include portal_user

do $$
begin
  alter type public.role_type add value if not exists 'portal_user';
exception
  when undefined_object then
    null;
end
$$;

alter table if exists public.users
  drop constraint if exists users_security_role_check;

alter table if exists public.users
  add constraint users_security_role_check
  check (security_role in ('standard', 'tester', 'internal', 'portal_user'));

create or replace function public.is_portal_user(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.users u
    where u.id = p_user_id
      and coalesce(u.security_role, 'standard') = 'portal_user'
  );
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
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type::text = row_environment_type
      and m.role::text in ('owner','super_admin','admin','manager','operator','viewer','portal_user')
      and (
        m.scope_type::text = 'org'
        or (m.scope_type::text = 'company' and m.company_id = row_company_id)
        or (m.scope_type::text = 'branch' and m.company_id = row_company_id and m.branch_id = row_branch_id)
        or m.scope_type::text = 'self'
      )
      and (
        not public.is_test_user(auth.uid())
        or public.is_sandbox_org(row_org_id)
      )
  )
$$;

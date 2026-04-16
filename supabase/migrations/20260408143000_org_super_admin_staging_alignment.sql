-- STAGING ONLY: promote team@lemmaofficial.com from tester to org_super_admin
-- Scope:
-- - security_role org_super_admin (platform identity)
-- - membership keeps super_admin as compatibility bridge for existing role_type enum
-- - helper and scope resolver alignment
-- - team account role/security alignment in sandbox org

ALTER TABLE IF EXISTS public.users
  DROP CONSTRAINT IF EXISTS users_security_role_check;

ALTER TABLE IF EXISTS public.users
  ADD CONSTRAINT users_security_role_check
  CHECK (security_role IN ('standard', 'tester', 'internal', 'portal_user', 'org_super_admin'));

CREATE OR REPLACE FUNCTION public.is_org_super_admin_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = p_user_id
      AND COALESCE(u.security_role, 'standard') = 'org_super_admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_scope(
  row_org_id uuid,
  row_company_id uuid,
  row_branch_id uuid,
  row_environment_type text
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.org_id = row_org_id
      AND (m.company_id IS NULL OR m.company_id = row_company_id)
      AND m.environment_type::text = row_environment_type
      AND m.role::text IN ('owner','super_admin','admin','manager','operator','viewer','portal_user')
      AND (
        m.scope_type::text = 'org'
        OR (m.scope_type::text = 'company' AND m.company_id = row_company_id)
        OR (m.scope_type::text = 'branch' AND m.company_id = row_company_id AND m.branch_id = row_branch_id)
        OR m.scope_type::text = 'self'
      )
      AND (
        NOT public.is_test_user(auth.uid())
        OR public.is_sandbox_org(row_org_id)
      )
  )
$$;

CREATE OR REPLACE FUNCTION public.can_write_scope(
  row_org_id uuid,
  row_company_id uuid,
  row_branch_id uuid,
  row_environment_type text
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.org_id = row_org_id
      AND (m.company_id IS NULL OR m.company_id = row_company_id)
      AND m.environment_type::text = row_environment_type
      AND m.role::text IN ('owner','super_admin','admin')
      AND (
        m.scope_type::text = 'org'
        OR (m.scope_type::text = 'company' AND m.company_id = row_company_id)
        OR (m.scope_type::text = 'branch' AND m.company_id = row_company_id AND m.branch_id = row_branch_id)
      )
      AND (
        NOT public.is_test_user(auth.uid())
        OR public.is_sandbox_org(row_org_id)
      )
  )
$$;

DO $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT au.id
  INTO v_user_id
  FROM auth.users au
  WHERE lower(au.email) = 'team@lemmaofficial.com'
  ORDER BY au.created_at ASC
  LIMIT 1;

  IF v_user_id IS NULL THEN
    SELECT u.id
    INTO v_user_id
    FROM public.users u
    WHERE lower(u.email) = 'team@lemmaofficial.com'
    ORDER BY u.created_at ASC
    LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'team@lemmaofficial.com not found in auth.users/public.users';
  END IF;

  UPDATE public.users
  SET
    security_role = 'org_super_admin',
    is_test = true,
    is_internal = false,
    environment_type = 'sandbox',
    is_demo = false,
    updated_at = now()
  WHERE id = v_user_id;

  UPDATE public.memberships
  SET
    role = 'super_admin',
    scope_type = 'company',
    org_id = '10000000-0000-0000-0000-0000000000aa',
    company_id = '20000000-0000-0000-0000-0000000000aa',
    branch_id = NULL,
    environment_type = 'sandbox',
    is_demo = false,
    is_test = true,
    updated_at = now(),
    updated_by = v_user_id
  WHERE user_id = v_user_id
    AND org_id = '10000000-0000-0000-0000-0000000000aa'
    AND company_id = '20000000-0000-0000-0000-0000000000aa'
    AND environment_type = 'sandbox';

  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = v_user_id
      AND m.org_id = '10000000-0000-0000-0000-0000000000aa'
      AND m.company_id = '20000000-0000-0000-0000-0000000000aa'
      AND m.environment_type = 'sandbox'
  ) THEN
    INSERT INTO public.memberships (
      id, user_id, org_id, company_id, branch_id, role, scope_type, environment_type, is_demo, is_test, created_by, updated_by
    ) VALUES (
      gen_random_uuid(),
      v_user_id,
      '10000000-0000-0000-0000-0000000000aa',
      '20000000-0000-0000-0000-0000000000aa',
      NULL,
      'super_admin',
      'company',
      'sandbox',
      false,
      true,
      v_user_id,
      v_user_id
    );
  END IF;
END
$$;

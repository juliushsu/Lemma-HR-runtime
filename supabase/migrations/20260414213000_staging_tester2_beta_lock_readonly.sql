-- STAGING ONLY
-- Minimum beta-lock allowlist grant for staging.tester2@lemma.local
--
-- Purpose:
-- - allow staging.tester2@lemma.local to pass staging beta lock
-- - keep the account in a read-only testing posture
-- - avoid widening allowlist scope
-- - avoid any writable enablement
--
-- Non-goals:
-- - no org_super_admin elevation
-- - no internal-wide grant
-- - no membership role promotion
-- - no additional account changes

do $$
declare
  v_user_id uuid;
begin
  select u.id into v_user_id
  from public.users u
  where lower(u.email) = 'staging.tester2@lemma.local'
  order by u.created_at asc
  limit 1;

  if v_user_id is null then
    raise exception 'staging.tester2@lemma.local not found in public.users';
  end if;

  update public.users
  set
    is_test = true,
    is_internal = false,
    security_role = 'tester',
    updated_at = now()
  where id = v_user_id;
end
$$;

-- Notes:
-- 1) Passing beta lock does not imply writable access.
-- 2) Writable remains controlled by membership role + app/runtime policy.
-- 3) This migration intentionally does not modify memberships.

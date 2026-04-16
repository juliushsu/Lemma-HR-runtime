do $$
declare
  v_org uuid := '10000000-0000-0000-0000-000000000001';
  v_company uuid := '20000000-0000-0000-0000-000000000001';
  v_user uuid := '90000000-0000-0000-0000-000000000001';
begin
  delete from auth.identities where user_id = v_user;
  delete from auth.users where id = v_user;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, is_sso_user, is_anonymous
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    v_user,
    'authenticated',
    'authenticated',
    'staging.tester@lemma.local',
    crypt('StagingTest#2026', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Staging Tester"}'::jsonb,
    now(),
    now(),
    false,
    false
  );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id
  )
  values (
    'staging.tester@lemma.local',
    v_user,
    jsonb_build_object('sub', v_user::text, 'email', 'staging.tester@lemma.local'),
    'email',
    now(),
    now(),
    now(),
    gen_random_uuid()
  )
  on conflict do nothing;

  insert into public.users (
    id, email, display_name, locale_preference, timezone, currency,
    environment_type, is_demo, created_by, updated_by
  )
  values (
    v_user,
    'staging.tester@lemma.local',
    'Staging Tester',
    'en',
    'Asia/Taipei',
    'TWD',
    'production',
    false,
    null,
    null
  )
  on conflict (id) do update
  set email = excluded.email,
      display_name = excluded.display_name,
      locale_preference = excluded.locale_preference,
      timezone = excluded.timezone,
      currency = excluded.currency,
      environment_type = excluded.environment_type,
      is_demo = excluded.is_demo,
      updated_at = now();

  insert into public.memberships (
    id, user_id, org_id, company_id, branch_id, role, scope_type,
    environment_type, is_demo, created_by, updated_by
  )
  values (
    '91000000-0000-0000-0000-000000000001',
    v_user,
    v_org,
    v_company,
    null,
    'admin',
    'company',
    'production',
    false,
    null,
    null
  )
  on conflict (id) do update
  set user_id = excluded.user_id,
      org_id = excluded.org_id,
      company_id = excluded.company_id,
      branch_id = excluded.branch_id,
      role = excluded.role,
      scope_type = excluded.scope_type,
      environment_type = excluded.environment_type,
      is_demo = excluded.is_demo,
      updated_at = now();
end $$;

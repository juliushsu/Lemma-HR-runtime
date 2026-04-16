-- STAGING ONLY
-- Allow juliushsu@gmail.com to pass beta lock without changing team@lemmaofficial.com model.

do $$
declare
  v_user_id uuid;
  v_actor_id uuid;
begin
  select u.id into v_actor_id
  from public.users u
  where lower(u.email) = 'team@lemmaofficial.com'
  limit 1;

  if v_actor_id is null then
    raise exception 'team@lemmaofficial.com not found in public.users';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_actor_id::text, 'email', 'team@lemmaofficial.com', 'role', 'service_role')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', v_actor_id::text, true);

  select u.id into v_user_id
  from public.users u
  where lower(u.email) = 'juliushsu@gmail.com'
  limit 1;

  if v_user_id is null then
    raise exception 'juliushsu@gmail.com not found in public.users';
  end if;

  update public.users
  set
    is_internal = true,
    security_role = coalesce(security_role, 'standard'),
    updated_at = now()
  where id = v_user_id;
end
$$;

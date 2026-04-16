-- Leave policy engine write ops v1 (staging)
-- Adds minimal write functions requested by product convergence.

drop policy if exists leave_entitlement_rules_delete on public.leave_entitlement_rules;
create policy leave_entitlement_rules_delete
on public.leave_entitlement_rules
for delete
using (leave_policy_can_write(org_id, company_id, environment_type));

drop function if exists public.disable_leave_type(uuid, uuid);
create function public.disable_leave_type(
  p_leave_type_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := coalesce(auth.uid(), p_actor_user_id);
  v_row public.leave_types%rowtype;
begin
  if auth.uid() is not null and p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'ACTOR_USER_MISMATCH';
  end if;
  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_REQUIRED';
  end if;

  update public.leave_types t
  set
    is_enabled = false,
    updated_at = now(),
    updated_by = v_actor_user_id
  where t.id = p_leave_type_id
  returning *
    into v_row;

  if not found then
    raise exception 'LEAVE_TYPE_NOT_FOUND';
  end if;

  return jsonb_build_object(
    'leave_type_id', v_row.id,
    'leave_type_code', v_row.leave_type_code,
    'is_enabled', v_row.is_enabled,
    'updated_at', v_row.updated_at
  );
end;
$$;

drop function if exists public.delete_leave_entitlement_rule(uuid, uuid);
create function public.delete_leave_entitlement_rule(
  p_rule_id uuid,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := coalesce(auth.uid(), p_actor_user_id);
  v_row public.leave_entitlement_rules%rowtype;
begin
  if auth.uid() is not null and p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'ACTOR_USER_MISMATCH';
  end if;
  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_REQUIRED';
  end if;

  delete from public.leave_entitlement_rules r
  where r.id = p_rule_id
  returning *
    into v_row;

  if not found then
    raise exception 'LEAVE_ENTITLEMENT_RULE_NOT_FOUND';
  end if;

  return jsonb_build_object(
    'rule_id', v_row.id,
    'deleted', true,
    'leave_policy_profile_id', v_row.leave_policy_profile_id,
    'leave_type_code', v_row.leave_type_code
  );
end;
$$;

drop function if exists public.create_leave_policy_decision(jsonb);
create function public.create_leave_policy_decision(
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_id uuid := coalesce(nullif(p_payload ->> 'id', '')::uuid, gen_random_uuid());
  v_org_id uuid := nullif(p_payload ->> 'org_id', '')::uuid;
  v_company_id uuid := nullif(p_payload ->> 'company_id', '')::uuid;
  v_policy_profile_id uuid := nullif(p_payload ->> 'policy_profile_id', '')::uuid;
  v_profile public.leave_policy_profiles%rowtype;
  v_environment_type text;
  v_is_demo boolean;
  v_decision_type text := nullif(trim(coalesce(p_payload ->> 'decision_type', '')), '');
  v_decision_title text := nullif(trim(coalesce(p_payload ->> 'decision_title', '')), '');
  v_decision_note text := nullif(trim(coalesce(p_payload ->> 'decision_note', '')), '');
  v_approved_by uuid := coalesce(nullif(p_payload ->> 'approved_by', '')::uuid, auth.uid());
  v_approved_at timestamptz := coalesce(nullif(p_payload ->> 'approved_at', '')::timestamptz, now());
  v_attachment_ref text := nullif(trim(coalesce(p_payload ->> 'attachment_ref', '')), '');
  v_actor_user_id uuid := auth.uid();
  v_row public.leave_policy_decisions%rowtype;
begin
  if v_org_id is null or v_company_id is null or v_policy_profile_id is null then
    raise exception 'DECISION_SCOPE_REQUIRED';
  end if;
  if v_decision_type is null or v_decision_title is null or v_decision_note is null then
    raise exception 'DECISION_REQUIRED_FIELDS_MISSING';
  end if;
  if v_approved_by is null then
    raise exception 'DECISION_APPROVER_REQUIRED';
  end if;

  select *
    into v_profile
  from public.leave_policy_profiles p
  where p.id = v_policy_profile_id
    and p.org_id = v_org_id
    and p.company_id = v_company_id;

  if not found then
    raise exception 'POLICY_PROFILE_NOT_FOUND';
  end if;

  v_environment_type := v_profile.environment_type;
  v_is_demo := v_profile.is_demo;

  insert into public.leave_policy_decisions (
    id,
    org_id,
    company_id,
    policy_profile_id,
    environment_type,
    is_demo,
    decision_type,
    decision_title,
    decision_note,
    approved_by,
    approved_at,
    attachment_ref,
    created_at,
    updated_at,
    created_by,
    updated_by
  ) values (
    v_id,
    v_org_id,
    v_company_id,
    v_policy_profile_id,
    v_environment_type,
    v_is_demo,
    v_decision_type,
    v_decision_title,
    v_decision_note,
    v_approved_by,
    v_approved_at,
    v_attachment_ref,
    now(),
    now(),
    v_actor_user_id,
    v_actor_user_id
  )
  returning *
    into v_row;

  return jsonb_build_object(
    'decision_id', v_row.id,
    'policy_profile_id', v_row.policy_profile_id,
    'decision_type', v_row.decision_type,
    'decision_title', v_row.decision_title,
    'approved_by', v_row.approved_by,
    'approved_at', v_row.approved_at,
    'created_at', v_row.created_at
  );
end;
$$;

grant execute on function public.disable_leave_type(uuid, uuid) to authenticated, service_role;
grant execute on function public.delete_leave_entitlement_rule(uuid, uuid) to authenticated, service_role;
grant execute on function public.create_leave_policy_decision(jsonb) to authenticated, service_role;

-- Onboarding flow functions v1 (staging)
-- Minimal read/write layer for invitation -> intake -> documents/consents/signatures -> review

create unique index if not exists employee_onboarding_consents_invitation_type_uidx
  on public.employee_onboarding_consents (invitation_id, consent_type);

create or replace function public.onboarding_record_access_log(
  p_org_id uuid,
  p_company_id uuid,
  p_environment_type environment_type,
  p_is_demo boolean,
  p_resource_type text,
  p_resource_id uuid,
  p_action text,
  p_reason text default null,
  p_granted_basis text default null,
  p_request_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_viewer_role text;
begin
  if v_user_id is null then
    return;
  end if;

  if not exists (select 1 from public.users u where u.id = v_user_id) then
    return;
  end if;

  select m.role::text
    into v_viewer_role
  from public.memberships m
  where m.user_id = v_user_id
    and m.org_id = p_org_id
    and (m.company_id is null or m.company_id = p_company_id)
    and m.environment_type = p_environment_type
  order by
    case m.role::text
      when 'owner' then 1
      when 'admin' then 2
      when 'manager' then 3
      when 'super_admin' then 4
      when 'operator' then 5
      when 'viewer' then 6
      else 9
    end
  limit 1;

  insert into public.employee_data_access_logs (
    org_id,
    company_id,
    environment_type,
    is_demo,
    viewer_user_id,
    viewer_role,
    resource_type,
    resource_id,
    action,
    reason,
    granted_basis,
    viewed_at,
    request_id,
    created_by,
    updated_by
  ) values (
    p_org_id,
    p_company_id,
    p_environment_type,
    p_is_demo,
    v_user_id,
    v_viewer_role,
    p_resource_type,
    p_resource_id,
    p_action,
    p_reason,
    p_granted_basis,
    now(),
    p_request_id,
    v_user_id,
    v_user_id
  );
exception
  when others then
    -- logging should never block onboarding flow
    null;
end;
$$;

revoke all on function public.onboarding_record_access_log(uuid, uuid, environment_type, boolean, text, uuid, text, text, text, text) from public;
grant execute on function public.onboarding_record_access_log(uuid, uuid, environment_type, boolean, text, uuid, text, text, text, text) to authenticated, service_role;

create or replace function public.list_onboarding_invitations(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  invitation_id uuid,
  invitee_name text,
  invitee_email text,
  invitee_phone text,
  preferred_language text,
  expected_start_date date,
  channel text,
  invitation_status text,
  onboarding_status text,
  expires_at timestamptz,
  submitted_at timestamptz,
  document_count bigint,
  pending_document_count bigint,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with doc_agg as (
    select
      d.invitation_id,
      count(*)::bigint as document_count,
      count(*) filter (where d.verification_status = 'pending')::bigint as pending_document_count
    from public.employee_onboarding_documents d
    group by d.invitation_id
  )
  select
    i.id as invitation_id,
    i.invitee_name,
    i.invitee_email,
    i.invitee_phone,
    i.preferred_language,
    i.expected_start_date,
    i.channel,
    i.status as invitation_status,
    t.onboarding_status,
    i.expires_at,
    t.submitted_at,
    coalesce(da.document_count, 0) as document_count,
    coalesce(da.pending_document_count, 0) as pending_document_count,
    greatest(i.updated_at, coalesce(t.updated_at, i.updated_at)) as updated_at
  from public.employee_onboarding_invitations i
  left join public.employee_onboarding_intake t on t.invitation_id = i.id
  left join doc_agg da on da.invitation_id = i.id
  where i.org_id = p_org_id
    and i.company_id = p_company_id
  order by i.created_at desc;
$$;

create or replace function public.get_onboarding_intake(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_inv public.employee_onboarding_invitations%rowtype;
  v_intake public.employee_onboarding_intake%rowtype;
  v_payload jsonb;
  v_resource_id uuid;
begin
  select *
    into v_inv
  from public.employee_onboarding_invitations
  where id = p_invitation_id;

  if not found then
    return null;
  end if;

  select *
    into v_intake
  from public.employee_onboarding_intake
  where invitation_id = p_invitation_id;

  v_payload := jsonb_build_object(
    'invitation', to_jsonb(v_inv) - 'token_hash',
    'intake', to_jsonb(v_intake),
    'documents', coalesce((
      select jsonb_agg(to_jsonb(d) order by d.created_at asc)
      from public.employee_onboarding_documents d
      where d.invitation_id = p_invitation_id
    ), '[]'::jsonb),
    'consents', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.created_at asc)
      from public.employee_onboarding_consents c
      where c.invitation_id = p_invitation_id
    ), '[]'::jsonb),
    'signatures', coalesce((
      select jsonb_agg(to_jsonb(s) order by s.signed_at asc)
      from public.employee_onboarding_signatures s
      where s.invitation_id = p_invitation_id
    ), '[]'::jsonb),
    'contract_deliveries', coalesce((
      select jsonb_agg(to_jsonb(cd) order by cd.delivered_at desc)
      from public.employee_contract_deliveries cd
      where cd.invitation_id = p_invitation_id
    ), '[]'::jsonb)
  );

  if onboarding_can_hr_read(v_inv.org_id, v_inv.company_id, v_inv.environment_type) then
    v_resource_id := coalesce(v_intake.id, p_invitation_id);
    perform public.onboarding_record_access_log(
      v_inv.org_id,
      v_inv.company_id,
      v_inv.environment_type,
      v_inv.is_demo,
      'intake',
      v_resource_id,
      'view',
      'hr_view_intake',
      null,
      null
    );
  end if;

  return v_payload;
end;
$$;

drop function if exists public.submit_onboarding_intake(uuid, jsonb);
create function public.submit_onboarding_intake(
  p_invitation_id uuid,
  p_payload jsonb
)
returns table (
  target_invitation_id uuid,
  intake_id uuid,
  onboarding_status text,
  submitted_at timestamptz,
  invitation_status text,
  updated_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_inv public.employee_onboarding_invitations%rowtype;
  v_intake_id uuid;
begin
  select *
    into v_inv
  from public.employee_onboarding_invitations
  where id = p_invitation_id;

  if not found then
    raise exception 'INVITATION_NOT_FOUND';
  end if;

  insert into public.employee_onboarding_intake (
    org_id,
    company_id,
    employee_id,
    invitation_id,
    environment_type,
    is_demo,
    onboarding_status,
    family_name_local,
    given_name_local,
    full_name_local,
    family_name_latin,
    given_name_latin,
    full_name_latin,
    birth_date,
    phone,
    email,
    address,
    emergency_contact_name,
    emergency_contact_phone,
    nationality_code,
    identity_document_type,
    is_foreign_worker,
    notes,
    submitted_at,
    updated_at,
    created_by,
    updated_by
  ) values (
    v_inv.org_id,
    v_inv.company_id,
    v_inv.employee_id,
    v_inv.id,
    v_inv.environment_type,
    v_inv.is_demo,
    'submitted',
    nullif(p_payload ->> 'family_name_local', ''),
    nullif(p_payload ->> 'given_name_local', ''),
    nullif(p_payload ->> 'full_name_local', ''),
    nullif(p_payload ->> 'family_name_latin', ''),
    nullif(p_payload ->> 'given_name_latin', ''),
    nullif(p_payload ->> 'full_name_latin', ''),
    nullif(p_payload ->> 'birth_date', '')::date,
    nullif(p_payload ->> 'phone', ''),
    nullif(p_payload ->> 'email', ''),
    nullif(p_payload ->> 'address', ''),
    nullif(p_payload ->> 'emergency_contact_name', ''),
    nullif(p_payload ->> 'emergency_contact_phone', ''),
    nullif(p_payload ->> 'nationality_code', ''),
    coalesce(nullif(p_payload ->> 'identity_document_type', ''), 'national_id'),
    coalesce((p_payload ->> 'is_foreign_worker')::boolean, false),
    nullif(p_payload ->> 'notes', ''),
    now(),
    now(),
    auth.uid(),
    auth.uid()
  )
  on conflict (invitation_id) do update
  set
    onboarding_status = 'submitted',
    family_name_local = excluded.family_name_local,
    given_name_local = excluded.given_name_local,
    full_name_local = excluded.full_name_local,
    family_name_latin = excluded.family_name_latin,
    given_name_latin = excluded.given_name_latin,
    full_name_latin = excluded.full_name_latin,
    birth_date = excluded.birth_date,
    phone = excluded.phone,
    email = excluded.email,
    address = excluded.address,
    emergency_contact_name = excluded.emergency_contact_name,
    emergency_contact_phone = excluded.emergency_contact_phone,
    nationality_code = excluded.nationality_code,
    identity_document_type = excluded.identity_document_type,
    is_foreign_worker = excluded.is_foreign_worker,
    notes = excluded.notes,
    submitted_at = now(),
    updated_at = now(),
    updated_by = auth.uid()
  returning id into v_intake_id;

  update public.employee_onboarding_invitations
  set
    status = 'submitted',
    accepted_at = coalesce(accepted_at, now()),
    updated_at = now(),
    updated_by = auth.uid()
  where id = p_invitation_id;

  return query
  select
    i.id as invitation_id,
    t.id as intake_id,
    t.onboarding_status,
    t.submitted_at,
    i.status as invitation_status,
    t.updated_at
  from public.employee_onboarding_invitations i
  join public.employee_onboarding_intake t on t.invitation_id = i.id
  where i.id = p_invitation_id;
end;
$$;

drop function if exists public.upsert_onboarding_consents(uuid, jsonb);
create function public.upsert_onboarding_consents(
  p_invitation_id uuid,
  p_payload jsonb
)
returns table (
  target_invitation_id uuid,
  total_consents int,
  checked_consents int,
  updated_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_inv public.employee_onboarding_invitations%rowtype;
  v_intake_id uuid;
  v_items jsonb;
  v_item jsonb;
  v_checked boolean;
  v_checked_at timestamptz;
begin
  select *
    into v_inv
  from public.employee_onboarding_invitations
  where id = p_invitation_id;

  if not found then
    raise exception 'INVITATION_NOT_FOUND';
  end if;

  select t.id
    into v_intake_id
  from public.employee_onboarding_intake t
  where t.invitation_id = p_invitation_id;

  if jsonb_typeof(p_payload) = 'array' then
    v_items := p_payload;
  elsif jsonb_typeof(p_payload -> 'items') = 'array' then
    v_items := p_payload -> 'items';
  else
    v_items := '[]'::jsonb;
  end if;

  for v_item in
    select value from jsonb_array_elements(v_items)
  loop
    v_checked := coalesce((v_item ->> 'is_checked')::boolean, false);
    v_checked_at := coalesce(nullif(v_item ->> 'checked_at', '')::timestamptz, case when v_checked then now() else null end);

    insert into public.employee_onboarding_consents (
      org_id,
      company_id,
      invitation_id,
      intake_id,
      environment_type,
      is_demo,
      consent_type,
      consent_version,
      consent_text_snapshot,
      is_checked,
      checked_at,
      ip_address,
      user_agent,
      created_by,
      updated_by
    ) values (
      v_inv.org_id,
      v_inv.company_id,
      v_inv.id,
      v_intake_id,
      v_inv.environment_type,
      v_inv.is_demo,
      coalesce(nullif(v_item ->> 'consent_type', ''), 'privacy_consent'),
      coalesce(nullif(v_item ->> 'consent_version', ''), 'v1'),
      coalesce(nullif(v_item ->> 'consent_text_snapshot', ''), ''),
      v_checked,
      v_checked_at,
      nullif(v_item ->> 'ip_address', '')::inet,
      nullif(v_item ->> 'user_agent', ''),
      auth.uid(),
      auth.uid()
    )
    on conflict (invitation_id, consent_type) do update
    set
      intake_id = excluded.intake_id,
      consent_version = excluded.consent_version,
      consent_text_snapshot = excluded.consent_text_snapshot,
      is_checked = excluded.is_checked,
      checked_at = excluded.checked_at,
      ip_address = excluded.ip_address,
      user_agent = excluded.user_agent,
      updated_at = now(),
      updated_by = auth.uid();
  end loop;

  return query
  select
    p_invitation_id as target_invitation_id,
    count(*)::int as total_consents,
    count(*) filter (where c.is_checked)::int as checked_consents,
    max(c.updated_at) as updated_at
  from public.employee_onboarding_consents c
  where c.invitation_id = p_invitation_id;
end;
$$;

create or replace function public.create_onboarding_signature(
  p_invitation_id uuid,
  p_signature_type text,
  p_storage_path text,
  p_signer_name text,
  p_signer_locale text,
  p_signature_storage_bucket text default 'onboarding-signatures'
)
returns table (
  signature_id uuid,
  invitation_id uuid,
  signature_type text,
  signature_storage_bucket text,
  signature_storage_path text,
  signed_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_inv public.employee_onboarding_invitations%rowtype;
  v_intake_id uuid;
  v_signature_id uuid;
begin
  if p_signature_type not in ('intake_confirmation', 'employment_contract') then
    raise exception 'INVALID_SIGNATURE_TYPE';
  end if;

  select * into v_inv
  from public.employee_onboarding_invitations
  where id = p_invitation_id;

  if not found then
    raise exception 'INVITATION_NOT_FOUND';
  end if;

  select t.id into v_intake_id
  from public.employee_onboarding_intake t
  where t.invitation_id = p_invitation_id;

  insert into public.employee_onboarding_signatures (
    org_id,
    company_id,
    employee_id,
    invitation_id,
    intake_id,
    environment_type,
    is_demo,
    signature_type,
    signature_storage_bucket,
    signature_storage_path,
    signed_at,
    signer_name,
    signer_locale,
    created_by,
    updated_by
  ) values (
    v_inv.org_id,
    v_inv.company_id,
    v_inv.employee_id,
    v_inv.id,
    v_intake_id,
    v_inv.environment_type,
    v_inv.is_demo,
    p_signature_type,
    coalesce(nullif(p_signature_storage_bucket, ''), 'onboarding-signatures'),
    p_storage_path,
    now(),
    p_signer_name,
    p_signer_locale,
    auth.uid(),
    auth.uid()
  ) returning id into v_signature_id;

  if p_signature_type = 'employment_contract' then
    with target_delivery as (
      select d.id
      from public.employee_contract_deliveries d
      where d.invitation_id = p_invitation_id
      order by d.delivered_at desc
      limit 1
    )
    update public.employee_contract_deliveries d
    set
      status = 'signed',
      signed_at = now(),
      updated_at = now(),
      updated_by = auth.uid()
    from target_delivery td
    where d.id = td.id;
  end if;

  perform public.onboarding_record_access_log(
    v_inv.org_id,
    v_inv.company_id,
    v_inv.environment_type,
    v_inv.is_demo,
    'signature',
    v_signature_id,
    'request',
    case when p_signature_type = 'employment_contract' then 'employee_signed_contract' else 'employee_signed_intake' end,
    null,
    null
  );

  return query
  select
    s.id,
    s.invitation_id,
    s.signature_type,
    s.signature_storage_bucket,
    s.signature_storage_path,
    s.signed_at
  from public.employee_onboarding_signatures s
  where s.id = v_signature_id;
end;
$$;

create or replace function public.create_onboarding_document(
  p_invitation_id uuid,
  p_doc_type text,
  p_storage_bucket text,
  p_storage_path text,
  p_file_name text,
  p_mime_type text,
  p_file_size_bytes bigint
)
returns table (
  document_id uuid,
  invitation_id uuid,
  doc_type text,
  storage_bucket text,
  storage_path text,
  verification_status text,
  sensitivity_level text,
  created_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_inv public.employee_onboarding_invitations%rowtype;
  v_intake_id uuid;
  v_doc_id uuid;
  v_sensitivity text;
begin
  if p_doc_type not in (
    'profile_photo',
    'national_id_front',
    'national_id_back',
    'education_certificate',
    'passport_page',
    'work_visa',
    'employment_contract'
  ) then
    raise exception 'INVALID_DOC_TYPE';
  end if;

  select * into v_inv
  from public.employee_onboarding_invitations
  where id = p_invitation_id;

  if not found then
    raise exception 'INVITATION_NOT_FOUND';
  end if;

  select t.id into v_intake_id
  from public.employee_onboarding_intake t
  where t.invitation_id = p_invitation_id;

  v_sensitivity := case
    when p_doc_type in ('national_id_front', 'national_id_back', 'passport_page', 'work_visa') then 'restricted'
    when p_doc_type = 'employment_contract' then 'high'
    else 'normal'
  end;

  insert into public.employee_onboarding_documents (
    org_id,
    company_id,
    employee_id,
    invitation_id,
    intake_id,
    environment_type,
    is_demo,
    doc_type,
    storage_bucket,
    storage_path,
    file_name,
    mime_type,
    file_size_bytes,
    sensitivity_level,
    is_required,
    verification_status,
    created_by,
    updated_by
  ) values (
    v_inv.org_id,
    v_inv.company_id,
    v_inv.employee_id,
    v_inv.id,
    v_intake_id,
    v_inv.environment_type,
    v_inv.is_demo,
    p_doc_type,
    p_storage_bucket,
    p_storage_path,
    p_file_name,
    p_mime_type,
    p_file_size_bytes,
    v_sensitivity,
    true,
    'pending',
    auth.uid(),
    auth.uid()
  ) returning id into v_doc_id;

  return query
  select
    d.id,
    d.invitation_id,
    d.doc_type,
    d.storage_bucket,
    d.storage_path,
    d.verification_status,
    d.sensitivity_level,
    d.created_at
  from public.employee_onboarding_documents d
  where d.id = v_doc_id;
end;
$$;

create or replace function public.list_onboarding_review_queue(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  invitation_id uuid,
  invitee_name text,
  preferred_language text,
  invitation_status text,
  onboarding_status text,
  is_foreign_worker boolean,
  submitted_at timestamptz,
  required_document_total int,
  uploaded_required_documents int,
  missing_required_documents int,
  pending_documents int,
  rejected_documents int,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with base as (
    select
      i.id,
      i.org_id,
      i.company_id,
      i.environment_type,
      i.invitee_name,
      i.preferred_language,
      i.status as invitation_status,
      t.onboarding_status,
      coalesce(t.is_foreign_worker, false) as is_foreign_worker,
      t.submitted_at,
      greatest(i.updated_at, coalesce(t.updated_at, i.updated_at)) as updated_at
    from public.employee_onboarding_invitations i
    left join public.employee_onboarding_intake t on t.invitation_id = i.id
    where i.org_id = p_org_id
      and i.company_id = p_company_id
      and (
        i.status in ('submitted', 'opened')
        or coalesce(t.onboarding_status, '') in ('submitted', 'hr_review')
      )
  ),
  expected_docs as (
    select
      b.id as invitation_id,
      case
        when b.is_foreign_worker then array['profile_photo','passport_page','work_visa']::text[]
        else array['profile_photo','national_id_front','national_id_back']::text[]
      end as required_doc_types
    from base b
  ),
  doc_agg as (
    select
      b.id as invitation_id,
      count(*) filter (where d.verification_status = 'pending')::int as pending_documents,
      count(*) filter (where d.verification_status = 'rejected')::int as rejected_documents
    from base b
    left join public.employee_onboarding_documents d on d.invitation_id = b.id
    group by b.id
  ),
  required_agg as (
    select
      e.invitation_id,
      cardinality(e.required_doc_types)::int as required_document_total,
      count(distinct d.doc_type)::int as uploaded_required_documents
    from expected_docs e
    left join public.employee_onboarding_documents d
      on d.invitation_id = e.invitation_id
     and d.doc_type = any(e.required_doc_types)
    group by e.invitation_id, e.required_doc_types
  )
  select
    b.id as invitation_id,
    b.invitee_name,
    b.preferred_language,
    b.invitation_status,
    b.onboarding_status,
    b.is_foreign_worker,
    b.submitted_at,
    coalesce(r.required_document_total, 0) as required_document_total,
    coalesce(r.uploaded_required_documents, 0) as uploaded_required_documents,
    greatest(coalesce(r.required_document_total, 0) - coalesce(r.uploaded_required_documents, 0), 0) as missing_required_documents,
    coalesce(d.pending_documents, 0) as pending_documents,
    coalesce(d.rejected_documents, 0) as rejected_documents,
    b.updated_at
  from base b
  left join required_agg r on r.invitation_id = b.id
  left join doc_agg d on d.invitation_id = b.id
  order by b.submitted_at desc nulls last, b.updated_at desc;
$$;

create or replace function public.mark_onboarding_document_verification(
  p_document_id uuid,
  p_verification_status text,
  p_rejection_reason text default null
)
returns table (
  document_id uuid,
  invitation_id uuid,
  verification_status text,
  rejection_reason text,
  verified_at timestamptz,
  verified_by uuid
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_doc public.employee_onboarding_documents%rowtype;
begin
  if p_verification_status not in ('pending', 'accepted', 'rejected') then
    raise exception 'INVALID_VERIFICATION_STATUS';
  end if;

  update public.employee_onboarding_documents d
  set
    verification_status = p_verification_status,
    rejection_reason = case when p_verification_status = 'rejected' then p_rejection_reason else null end,
    verified_at = now(),
    verified_by = auth.uid(),
    updated_at = now(),
    updated_by = auth.uid()
  where d.id = p_document_id
  returning * into v_doc;

  if not found then
    raise exception 'DOCUMENT_NOT_FOUND';
  end if;

  perform public.onboarding_record_access_log(
    v_doc.org_id,
    v_doc.company_id,
    v_doc.environment_type,
    v_doc.is_demo,
    'document',
    v_doc.id,
    'verify',
    case when p_verification_status = 'rejected' then 'hr_reject_document' else 'hr_verify_document' end,
    null,
    null
  );

  return query
  select
    v_doc.id,
    v_doc.invitation_id,
    v_doc.verification_status,
    v_doc.rejection_reason,
    v_doc.verified_at,
    v_doc.verified_by;
end;
$$;

create or replace function public.create_contract_delivery(
  p_invitation_id uuid,
  p_legal_document_id uuid,
  p_delivery_channel text,
  p_delivery_ref text default null
)
returns table (
  delivery_id uuid,
  invitation_id uuid,
  legal_document_id uuid,
  delivery_channel text,
  status text,
  delivered_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_inv public.employee_onboarding_invitations%rowtype;
  v_delivery_id uuid;
begin
  if p_delivery_channel not in ('line', 'link') then
    raise exception 'INVALID_DELIVERY_CHANNEL';
  end if;

  select * into v_inv
  from public.employee_onboarding_invitations
  where id = p_invitation_id;

  if not found then
    raise exception 'INVITATION_NOT_FOUND';
  end if;

  insert into public.employee_contract_deliveries (
    org_id,
    company_id,
    employee_id,
    invitation_id,
    legal_document_id,
    environment_type,
    is_demo,
    delivery_channel,
    delivered_at,
    status,
    delivery_ref,
    created_by,
    updated_by
  ) values (
    v_inv.org_id,
    v_inv.company_id,
    v_inv.employee_id,
    v_inv.id,
    p_legal_document_id,
    v_inv.environment_type,
    v_inv.is_demo,
    p_delivery_channel,
    now(),
    'sent',
    p_delivery_ref,
    auth.uid(),
    auth.uid()
  ) returning id into v_delivery_id;

  perform public.onboarding_record_access_log(
    v_inv.org_id,
    v_inv.company_id,
    v_inv.environment_type,
    v_inv.is_demo,
    'contract_delivery',
    v_delivery_id,
    'send',
    'hr_send_contract',
    null,
    null
  );

  return query
  select
    d.id,
    d.invitation_id,
    d.legal_document_id,
    d.delivery_channel,
    d.status,
    d.delivered_at
  from public.employee_contract_deliveries d
  where d.id = v_delivery_id;
end;
$$;

create or replace function public.log_onboarding_document_download(
  p_document_id uuid,
  p_reason text default null
)
returns void
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_doc public.employee_onboarding_documents%rowtype;
begin
  select * into v_doc
  from public.employee_onboarding_documents
  where id = p_document_id;

  if not found then
    raise exception 'DOCUMENT_NOT_FOUND';
  end if;

  perform public.onboarding_record_access_log(
    v_doc.org_id,
    v_doc.company_id,
    v_doc.environment_type,
    v_doc.is_demo,
    'document',
    v_doc.id,
    'download',
    coalesce(p_reason, 'hr_download_document'),
    null,
    null
  );
end;
$$;

revoke all on function public.list_onboarding_invitations(uuid, uuid) from public;
revoke all on function public.get_onboarding_intake(uuid) from public;
revoke all on function public.submit_onboarding_intake(uuid, jsonb) from public;
revoke all on function public.upsert_onboarding_consents(uuid, jsonb) from public;
revoke all on function public.create_onboarding_signature(uuid, text, text, text, text, text) from public;
revoke all on function public.create_onboarding_document(uuid, text, text, text, text, text, bigint) from public;
revoke all on function public.list_onboarding_review_queue(uuid, uuid) from public;
revoke all on function public.mark_onboarding_document_verification(uuid, text, text) from public;
revoke all on function public.create_contract_delivery(uuid, uuid, text, text) from public;
revoke all on function public.log_onboarding_document_download(uuid, text) from public;

grant execute on function public.list_onboarding_invitations(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_onboarding_intake(uuid) to authenticated, service_role;
grant execute on function public.submit_onboarding_intake(uuid, jsonb) to authenticated, service_role;
grant execute on function public.upsert_onboarding_consents(uuid, jsonb) to authenticated, service_role;
grant execute on function public.create_onboarding_signature(uuid, text, text, text, text, text) to authenticated, service_role;
grant execute on function public.create_onboarding_document(uuid, text, text, text, text, text, bigint) to authenticated, service_role;
grant execute on function public.list_onboarding_review_queue(uuid, uuid) to authenticated, service_role;
grant execute on function public.mark_onboarding_document_verification(uuid, text, text) to authenticated, service_role;
grant execute on function public.create_contract_delivery(uuid, uuid, text, text) to authenticated, service_role;
grant execute on function public.log_onboarding_document_download(uuid, text) to authenticated, service_role;

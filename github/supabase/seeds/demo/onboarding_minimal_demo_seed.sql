-- Onboarding minimal demo seed (staging demo scope only)

with scope as (
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::environment_type as environment_type,
    true as is_demo,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as demo_admin_user_id,
    'b0000000-0000-0000-0000-000000000101'::uuid as demo_employment_contract_id,
    '71000000-0000-0000-0000-000000000101'::uuid as emp_local,
    '71000000-0000-0000-0000-000000000102'::uuid as emp_foreign,
    '71000000-0000-0000-0000-000000000103'::uuid as emp_pending
)
insert into public.employee_onboarding_invitations (
  id, org_id, company_id, employee_id, environment_type, is_demo,
  invitee_name, invitee_phone, invitee_email, preferred_language, expected_start_date,
  channel, token_hash, token_last4, expires_at, accepted_at, status,
  invited_by, reviewed_by, reviewed_at, created_at, updated_at, created_by, updated_by
)
select * from (
  select
    '81000000-0000-0000-0000-000000000201'::uuid,
    s.org_id, s.company_id, s.emp_local, s.environment_type, s.is_demo,
    '林雅婷', '+886912000001', 'demo.newhire.local@lemma.local', 'zh-TW', current_date + 7,
    'link', 'seed_local_case_token_hash_v1', 'A201', now() + interval '30 days', now() - interval '3 days', 'submitted',
    s.demo_admin_user_id, s.demo_admin_user_id, now() - interval '1 day', now() - interval '7 days', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select
    '81000000-0000-0000-0000-000000000202'::uuid,
    s.org_id, s.company_id, s.emp_foreign, s.environment_type, s.is_demo,
    'Sokha Chenda', '+85512000002', 'demo.newhire.foreign@lemma.local', 'en', current_date + 10,
    'line', 'seed_foreign_case_token_hash_v1', 'A202', now() + interval '30 days', now() - interval '2 days', 'opened',
    s.demo_admin_user_id, null, null, now() - interval '6 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select
    '81000000-0000-0000-0000-000000000203'::uuid,
    s.org_id, s.company_id, s.emp_pending, s.environment_type, s.is_demo,
    '김민준', '+821012300003', 'demo.newhire.pending@lemma.local', 'ko', current_date + 5,
    'link', 'seed_pending_case_token_hash_v1', 'A203', now() + interval '30 days', now() - interval '1 day', 'submitted',
    s.demo_admin_user_id, null, null, now() - interval '5 days', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
) v
on conflict (id) do update set
  invitee_name = excluded.invitee_name,
  invitee_phone = excluded.invitee_phone,
  invitee_email = excluded.invitee_email,
  preferred_language = excluded.preferred_language,
  expected_start_date = excluded.expected_start_date,
  channel = excluded.channel,
  token_hash = excluded.token_hash,
  token_last4 = excluded.token_last4,
  expires_at = excluded.expires_at,
  accepted_at = excluded.accepted_at,
  status = excluded.status,
  invited_by = excluded.invited_by,
  reviewed_by = excluded.reviewed_by,
  reviewed_at = excluded.reviewed_at,
  updated_at = excluded.updated_at,
  updated_by = excluded.updated_by;

with scope as (
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::environment_type as environment_type,
    true as is_demo,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as demo_admin_user_id,
    '71000000-0000-0000-0000-000000000101'::uuid as emp_local,
    '71000000-0000-0000-0000-000000000102'::uuid as emp_foreign,
    '71000000-0000-0000-0000-000000000103'::uuid as emp_pending
)
insert into public.employee_onboarding_intake (
  id, org_id, company_id, employee_id, invitation_id, environment_type, is_demo,
  onboarding_status,
  family_name_local, given_name_local, full_name_local,
  family_name_latin, given_name_latin, full_name_latin,
  birth_date, phone, email, address,
  emergency_contact_name, emergency_contact_phone,
  nationality_code, identity_document_type, is_foreign_worker, notes,
  submitted_at, approved_at, approved_by,
  created_at, updated_at, created_by, updated_by
)
select * from (
  select
    '82000000-0000-0000-0000-000000000201'::uuid,
    s.org_id, s.company_id, s.emp_local, '81000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
    'approved',
    '林', '雅婷', '林雅婷',
    'Lin', 'Yating', 'Yating Lin',
    '1995-08-12'::date, '+886912000001', 'demo.newhire.local@lemma.local', 'Taipei, Taiwan',
    '林文華', '+886912999001',
    'TW', 'national_id', false, 'Local employee completed onboarding.',
    now() - interval '3 days', now() - interval '1 day', s.demo_admin_user_id,
    now() - interval '3 days', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select
    '82000000-0000-0000-0000-000000000202'::uuid,
    s.org_id, s.company_id, s.emp_foreign, '81000000-0000-0000-0000-000000000202'::uuid, s.environment_type, s.is_demo,
    'hr_review',
    '陳', '索卡', '陳索卡',
    'Sokha', 'Chenda', 'Sokha Chenda',
    '1997-03-05'::date, '+85512000002', 'demo.newhire.foreign@lemma.local', 'Phnom Penh, Cambodia',
    'Sokun Neang', '+85512999888',
    'KH', 'passport', true, 'Foreign worker; visa verification pending.',
    now() - interval '2 days', null, null,
    now() - interval '2 days', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select
    '82000000-0000-0000-0000-000000000203'::uuid,
    s.org_id, s.company_id, s.emp_pending, '81000000-0000-0000-0000-000000000203'::uuid, s.environment_type, s.is_demo,
    'submitted',
    '김', '민준', '김민준',
    'Kim', 'Minjun', 'Minjun Kim',
    '2000-11-14'::date, '+821012300003', 'demo.newhire.pending@lemma.local', 'Busan, South Korea',
    '김서연', '+821055500003',
    'KR', 'national_id', false, 'Submitted but missing required document.',
    now() - interval '1 day', null, null,
    now() - interval '1 day', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
) v
on conflict (id) do update set
  onboarding_status = excluded.onboarding_status,
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
  submitted_at = excluded.submitted_at,
  approved_at = excluded.approved_at,
  approved_by = excluded.approved_by,
  updated_at = excluded.updated_at,
  updated_by = excluded.updated_by;

with scope as (
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::environment_type as environment_type,
    true as is_demo,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as demo_admin_user_id
)
insert into public.employee_onboarding_documents (
  id, org_id, company_id, employee_id, invitation_id, intake_id, environment_type, is_demo,
  doc_type, storage_bucket, storage_path, file_name, mime_type, file_size_bytes,
  sensitivity_level, is_required, verification_status,
  verified_by, verified_at, rejection_reason,
  created_at, updated_at, created_by, updated_by
)
select * from (
  -- Case 1: local complete
  select '83000000-0000-0000-0000-000000000211'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000101'::uuid, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'profile_photo', 'onboarding-documents', 'demo/810...201/profile_photo.jpg', 'profile_photo.jpg', 'image/jpeg', 320000,
         'normal', true, 'accepted', s.demo_admin_user_id, now() - interval '2 days', null,
         now() - interval '3 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '83000000-0000-0000-0000-000000000212'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000101'::uuid, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'national_id_front', 'onboarding-documents', 'demo/810...201/national_id_front.jpg', 'national_id_front.jpg', 'image/jpeg', 420000,
         'restricted', true, 'accepted', s.demo_admin_user_id, now() - interval '2 days', null,
         now() - interval '3 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '83000000-0000-0000-0000-000000000213'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000101'::uuid, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'national_id_back', 'onboarding-documents', 'demo/810...201/national_id_back.jpg', 'national_id_back.jpg', 'image/jpeg', 410000,
         'restricted', true, 'accepted', s.demo_admin_user_id, now() - interval '2 days', null,
         now() - interval '3 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s

  -- Case 2: foreign worker
  union all
  select '83000000-0000-0000-0000-000000000221'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000102'::uuid, '81000000-0000-0000-0000-000000000202'::uuid, '82000000-0000-0000-0000-000000000202'::uuid, s.environment_type, s.is_demo,
         'profile_photo', 'onboarding-documents', 'demo/810...202/profile_photo.jpg', 'profile_photo.jpg', 'image/jpeg', 305000,
         'normal', true, 'accepted', s.demo_admin_user_id, now() - interval '1 day', null,
         now() - interval '2 days', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '83000000-0000-0000-0000-000000000222'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000102'::uuid, '81000000-0000-0000-0000-000000000202'::uuid, '82000000-0000-0000-0000-000000000202'::uuid, s.environment_type, s.is_demo,
         'passport_page', 'onboarding-documents', 'demo/810...202/passport_page.pdf', 'passport_page.pdf', 'application/pdf', 780000,
         'restricted', true, 'accepted', s.demo_admin_user_id, now() - interval '1 day', null,
         now() - interval '2 days', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '83000000-0000-0000-0000-000000000223'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000102'::uuid, '81000000-0000-0000-0000-000000000202'::uuid, '82000000-0000-0000-0000-000000000202'::uuid, s.environment_type, s.is_demo,
         'work_visa', 'onboarding-documents', 'demo/810...202/work_visa.pdf', 'work_visa.pdf', 'application/pdf', 660000,
         'restricted', true, 'pending', null, null, null,
         now() - interval '2 days', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s

  -- Case 3: pending / missing docs
  union all
  select '83000000-0000-0000-0000-000000000231'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000103'::uuid, '81000000-0000-0000-0000-000000000203'::uuid, '82000000-0000-0000-0000-000000000203'::uuid, s.environment_type, s.is_demo,
         'profile_photo', 'onboarding-documents', 'demo/810...203/profile_photo.jpg', 'profile_photo.jpg', 'image/jpeg', 300000,
         'normal', true, 'pending', null, null, null,
         now() - interval '1 day', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
) v
on conflict (id) do update set
  verification_status = excluded.verification_status,
  verified_by = excluded.verified_by,
  verified_at = excluded.verified_at,
  rejection_reason = excluded.rejection_reason,
  updated_at = excluded.updated_at,
  updated_by = excluded.updated_by,
  storage_path = excluded.storage_path,
  file_name = excluded.file_name,
  file_size_bytes = excluded.file_size_bytes;

with scope as (
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::environment_type as environment_type,
    true as is_demo,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as demo_admin_user_id
)
insert into public.employee_onboarding_consents (
  id, org_id, company_id, invitation_id, intake_id, environment_type, is_demo,
  consent_type, consent_version, consent_text_snapshot,
  is_checked, checked_at, ip_address, user_agent,
  created_at, updated_at, created_by, updated_by
)
select * from (
  -- Case 1
  select '84000000-0000-0000-0000-000000000211'::uuid, s.org_id, s.company_id, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'data_accuracy_declaration', 'v1', 'I confirm all personal data is accurate.',
         true, now() - interval '3 days', '10.10.10.21'::inet, 'Demo WebView/1.0',
         now() - interval '3 days', now() - interval '3 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '84000000-0000-0000-0000-000000000212'::uuid, s.org_id, s.company_id, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'privacy_consent', 'v1', 'I consent to privacy policy processing.',
         true, now() - interval '3 days', '10.10.10.21'::inet, 'Demo WebView/1.0',
         now() - interval '3 days', now() - interval '3 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '84000000-0000-0000-0000-000000000213'::uuid, s.org_id, s.company_id, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'employment_terms_acknowledgement', 'v1', 'I acknowledge employment terms.',
         true, now() - interval '3 days', '10.10.10.21'::inet, 'Demo WebView/1.0',
         now() - interval '3 days', now() - interval '3 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s

  -- Case 2
  union all
  select '84000000-0000-0000-0000-000000000221'::uuid, s.org_id, s.company_id, '81000000-0000-0000-0000-000000000202'::uuid, '82000000-0000-0000-0000-000000000202'::uuid, s.environment_type, s.is_demo,
         'data_accuracy_declaration', 'v1', 'Data accuracy declaration.',
         true, now() - interval '2 days', '10.10.10.22'::inet, 'LIFF/2.0',
         now() - interval '2 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '84000000-0000-0000-0000-000000000222'::uuid, s.org_id, s.company_id, '81000000-0000-0000-0000-000000000202'::uuid, '82000000-0000-0000-0000-000000000202'::uuid, s.environment_type, s.is_demo,
         'privacy_consent', 'v1', 'Privacy consent for HR onboarding.',
         true, now() - interval '2 days', '10.10.10.22'::inet, 'LIFF/2.0',
         now() - interval '2 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s

  -- Case 3 (partial)
  union all
  select '84000000-0000-0000-0000-000000000231'::uuid, s.org_id, s.company_id, '81000000-0000-0000-0000-000000000203'::uuid, '82000000-0000-0000-0000-000000000203'::uuid, s.environment_type, s.is_demo,
         'privacy_consent', 'v1', 'Privacy consent checked only; others pending.',
         true, now() - interval '1 day', '10.10.10.23'::inet, 'LIFF/2.0',
         now() - interval '1 day', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
) v
on conflict (id) do update set
  consent_version = excluded.consent_version,
  consent_text_snapshot = excluded.consent_text_snapshot,
  is_checked = excluded.is_checked,
  checked_at = excluded.checked_at,
  ip_address = excluded.ip_address,
  user_agent = excluded.user_agent,
  updated_at = excluded.updated_at,
  updated_by = excluded.updated_by;

with scope as (
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::environment_type as environment_type,
    true as is_demo,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as demo_admin_user_id
)
insert into public.employee_onboarding_signatures (
  id, org_id, company_id, employee_id, invitation_id, intake_id, environment_type, is_demo,
  signature_type, signature_storage_bucket, signature_storage_path,
  signed_at, signer_name, signer_locale, ip_address, user_agent,
  created_at, updated_at, created_by, updated_by
)
select * from (
  -- Case 1 signatures
  select '85000000-0000-0000-0000-000000000211'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000101'::uuid, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'intake_confirmation', 'onboarding-signatures', 'demo/810...201/signature_intake.png',
         now() - interval '3 days', '林雅婷', 'zh-TW', '10.10.10.21'::inet, 'Demo WebView/1.0',
         now() - interval '3 days', now() - interval '3 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '85000000-0000-0000-0000-000000000212'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000101'::uuid, '81000000-0000-0000-0000-000000000201'::uuid, '82000000-0000-0000-0000-000000000201'::uuid, s.environment_type, s.is_demo,
         'employment_contract', 'onboarding-signatures', 'demo/810...201/signature_contract.png',
         now() - interval '2 days', '林雅婷', 'zh-TW', '10.10.10.21'::inet, 'Demo WebView/1.0',
         now() - interval '2 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s

  -- Case 2 signature
  union all
  select '85000000-0000-0000-0000-000000000221'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000102'::uuid, '81000000-0000-0000-0000-000000000202'::uuid, '82000000-0000-0000-0000-000000000202'::uuid, s.environment_type, s.is_demo,
         'intake_confirmation', 'onboarding-signatures', 'demo/810...202/signature_intake.png',
         now() - interval '2 days', 'Sokha Chenda', 'en', '10.10.10.22'::inet, 'LIFF/2.0',
         now() - interval '2 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
) v
on conflict (id) do update set
  signature_storage_path = excluded.signature_storage_path,
  signed_at = excluded.signed_at,
  signer_name = excluded.signer_name,
  signer_locale = excluded.signer_locale,
  updated_at = excluded.updated_at,
  updated_by = excluded.updated_by;

with scope as (
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::environment_type as environment_type,
    true as is_demo,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as demo_admin_user_id,
    'b0000000-0000-0000-0000-000000000101'::uuid as employment_doc_id
)
insert into public.employee_contract_deliveries (
  id, org_id, company_id, employee_id, invitation_id, legal_document_id, environment_type, is_demo,
  delivery_channel, delivered_at, opened_at, signed_at, status, delivery_ref,
  created_at, updated_at, created_by, updated_by
)
select * from (
  select '86000000-0000-0000-0000-000000000211'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000101'::uuid, '81000000-0000-0000-0000-000000000201'::uuid, s.employment_doc_id, s.environment_type, s.is_demo,
         'line', now() - interval '3 days', now() - interval '3 days' + interval '2 hours', now() - interval '2 days', 'signed', 'line-msg-201',
         now() - interval '3 days', now() - interval '2 days', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '86000000-0000-0000-0000-000000000221'::uuid, s.org_id, s.company_id, '71000000-0000-0000-0000-000000000102'::uuid, '81000000-0000-0000-0000-000000000202'::uuid, s.employment_doc_id, s.environment_type, s.is_demo,
         'link', now() - interval '1 day', null, null, 'sent', 'link-token-202',
         now() - interval '1 day', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
) v
on conflict (id) do update set
  opened_at = excluded.opened_at,
  signed_at = excluded.signed_at,
  status = excluded.status,
  delivery_ref = excluded.delivery_ref,
  updated_at = excluded.updated_at,
  updated_by = excluded.updated_by;

with scope as (
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::environment_type as environment_type,
    true as is_demo,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as demo_admin_user_id
)
insert into public.employee_data_access_logs (
  id, org_id, company_id, environment_type, is_demo,
  viewer_user_id, viewer_role,
  resource_type, resource_id, action, reason, granted_basis,
  viewed_at, request_id,
  created_at, updated_at, created_by, updated_by
)
select * from (
  select '87000000-0000-0000-0000-000000000211'::uuid, s.org_id, s.company_id, s.environment_type, s.is_demo,
         s.demo_admin_user_id, 'admin',
         'intake', '82000000-0000-0000-0000-000000000201'::uuid, 'view', 'hr_view_intake', 'role_scope_policy',
         now() - interval '1 day', 'seed-req-intake-view-201',
         now() - interval '1 day', now() - interval '1 day', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '87000000-0000-0000-0000-000000000212'::uuid, s.org_id, s.company_id, s.environment_type, s.is_demo,
         s.demo_admin_user_id, 'admin',
         'document', '83000000-0000-0000-0000-000000000212'::uuid, 'download', 'hr_download_document', 'role_scope_policy',
         now() - interval '23 hours', 'seed-req-doc-download-212',
         now() - interval '23 hours', now() - interval '23 hours', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '87000000-0000-0000-0000-000000000213'::uuid, s.org_id, s.company_id, s.environment_type, s.is_demo,
         s.demo_admin_user_id, 'admin',
         'document', '83000000-0000-0000-0000-000000000223'::uuid, 'verify', 'hr_verify_document', 'role_scope_policy',
         now() - interval '20 hours', 'seed-req-doc-verify-223',
         now() - interval '20 hours', now() - interval '20 hours', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '87000000-0000-0000-0000-000000000214'::uuid, s.org_id, s.company_id, s.environment_type, s.is_demo,
         s.demo_admin_user_id, 'admin',
         'contract_delivery', '86000000-0000-0000-0000-000000000211'::uuid, 'send', 'hr_send_contract', 'role_scope_policy',
         now() - interval '18 hours', 'seed-req-contract-send-211',
         now() - interval '18 hours', now() - interval '18 hours', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
  union all
  select '87000000-0000-0000-0000-000000000215'::uuid, s.org_id, s.company_id, s.environment_type, s.is_demo,
         s.demo_admin_user_id, 'admin',
         'signature', '85000000-0000-0000-0000-000000000212'::uuid, 'request', 'employee_signed_contract', 'signature_capture',
         now() - interval '16 hours', 'seed-req-signature-212',
         now() - interval '16 hours', now() - interval '16 hours', s.demo_admin_user_id, s.demo_admin_user_id
  from scope s
) v
on conflict (id) do update set
  action = excluded.action,
  reason = excluded.reason,
  granted_basis = excluded.granted_basis,
  viewed_at = excluded.viewed_at,
  request_id = excluded.request_id,
  updated_at = excluded.updated_at,
  updated_by = excluded.updated_by;

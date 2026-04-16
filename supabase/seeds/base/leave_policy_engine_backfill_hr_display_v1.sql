-- Leave policy + HR display backfill seed (staging only)

-- ---------------------------------------------------------------------------
-- A) Ensure policy profile core rows exist
-- ---------------------------------------------------------------------------
insert into public.leave_policy_profiles (
  org_id, company_id, environment_type, is_demo,
  country_code, policy_name, effective_from, effective_to,
  leave_year_mode, holiday_mode, allow_cross_country_holiday_merge,
  payroll_policy_mode, compliance_warning_enabled, notes
) values
  (
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    'demo', true,
    'TW', 'TW Leave Policy 2026 (Demo)', '2026-01-01', null,
    'calendar_year', 'official_calendar', false,
    'strict', true, 'TW baseline (backfill)'
  ),
  (
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    'production', false,
    'JP', 'JP Leave Policy 2026', '2026-01-01', null,
    'anniversary_year', 'official_calendar', false,
    'custom', true, 'JP baseline (backfill)'
  )
on conflict (org_id, company_id, country_code, policy_name, effective_from, environment_type)
do update set
  leave_year_mode = excluded.leave_year_mode,
  holiday_mode = excluded.holiday_mode,
  payroll_policy_mode = excluded.payroll_policy_mode,
  compliance_warning_enabled = excluded.compliance_warning_enabled,
  notes = excluded.notes,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- B) Ensure key leave types exist (TW/JP)
-- ---------------------------------------------------------------------------
insert into public.leave_types (
  org_id, company_id, leave_policy_profile_id, environment_type, is_demo,
  leave_type_code, display_name, is_paid, affects_payroll,
  requires_attachment, requires_approval, sort_order, is_enabled
)
select
  s.org_id, s.company_id, s.leave_policy_profile_id, s.environment_type, s.is_demo,
  s.leave_type_code, s.display_name, s.is_paid, s.affects_payroll,
  s.requires_attachment, s.requires_approval, s.sort_order, s.is_enabled
from (
  -- TW key types
  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),
    'demo'::text,
    true,
    'annual_leave'::text,
    '特休假'::text,
    true, true,
    false, true,
    10, true
  union all
  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),
    'demo',
    true,
    'sick_leave',
    '病假',
    true, true,
    true, true,
    20, true
  union all
  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),
    'demo',
    true,
    'personal_leave',
    '事假',
    false, true,
    false, true,
    30, true
  union all
  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),
    'demo',
    true,
    'unpaid_leave',
    '無薪假',
    false, true,
    false, true,
    40, true

  union all

  -- JP key types
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),
    'production',
    false,
    'annual_leave',
    '年次休暇',
    true, true,
    false, true,
    10, true
  union all
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),
    'production',
    false,
    'paid_leave',
    '有給休暇',
    true, true,
    false, true,
    20, true
  union all
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),
    'production',
    false,
    'sick_leave',
    '病気休暇',
    false, true,
    true, true,
    30, true
  union all
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),
    'production',
    false,
    'unpaid_leave',
    '無給休暇',
    false, true,
    false, true,
    40, true
) s(
  org_id, company_id, leave_policy_profile_id, environment_type, is_demo,
  leave_type_code, display_name, is_paid, affects_payroll,
  requires_attachment, requires_approval, sort_order, is_enabled
)
where s.leave_policy_profile_id is not null
on conflict (org_id, company_id, leave_policy_profile_id, leave_type_code, environment_type)
do update set
  display_name = excluded.display_name,
  is_paid = excluded.is_paid,
  affects_payroll = excluded.affects_payroll,
  requires_attachment = excluded.requires_attachment,
  requires_approval = excluded.requires_approval,
  sort_order = excluded.sort_order,
  is_enabled = excluded.is_enabled,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- C) Ensure key entitlement rules exist
-- ---------------------------------------------------------------------------
insert into public.leave_entitlement_rules (
  org_id, company_id, leave_policy_profile_id, environment_type, is_demo,
  leave_type_code, accrual_mode, tenure_months_from, tenure_months_to,
  granted_days, max_days_cap, carry_forward_mode, carry_forward_days,
  effective_from, effective_to
)
select
  r.org_id, r.company_id, r.leave_policy_profile_id, r.environment_type, r.is_demo,
  r.leave_type_code, r.accrual_mode, r.tenure_months_from, r.tenure_months_to,
  r.granted_days, r.max_days_cap, r.carry_forward_mode, r.carry_forward_days,
  r.effective_from, r.effective_to
from (
  -- TW annual rules
  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),
    'demo'::text,
    true,
    'annual_leave'::text,
    'calendar'::text,
    12::int,
    23::int,
    7.0::numeric,
    30.0::numeric,
    'limited'::text,
    5.0::numeric,
    '2026-01-01'::date,
    null::date
  union all
  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),
    'demo',
    true,
    'annual_leave',
    'anniversary',
    24,
    null,
    10.0,
    45.0,
    'limited',
    10.0,
    '2026-01-01',
    null

  union all

  -- JP annual + paid rules
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),
    'production',
    false,
    'annual_leave',
    'anniversary',
    12,
    23,
    10.0,
    40.0,
    'limited',
    20.0,
    '2026-01-01',
    null
  union all
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),
    'production',
    false,
    'paid_leave',
    'anniversary',
    6,
    11,
    10.0,
    40.0,
    'limited',
    20.0,
    '2026-01-01',
    null
  union all
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),
    'production',
    false,
    'paid_leave',
    'anniversary',
    12,
    23,
    11.0,
    45.0,
    'limited',
    20.0,
    '2026-01-01',
    null
) r(
  org_id, company_id, leave_policy_profile_id, environment_type, is_demo,
  leave_type_code, accrual_mode, tenure_months_from, tenure_months_to,
  granted_days, max_days_cap, carry_forward_mode, carry_forward_days,
  effective_from, effective_to
)
where r.leave_policy_profile_id is not null
on conflict (org_id, company_id, leave_policy_profile_id, leave_type_code, accrual_mode, tenure_months_from, effective_from, environment_type)
do update set
  tenure_months_to = excluded.tenure_months_to,
  granted_days = excluded.granted_days,
  max_days_cap = excluded.max_days_cap,
  carry_forward_mode = excluded.carry_forward_mode,
  carry_forward_days = excluded.carry_forward_days,
  effective_to = excluded.effective_to,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- D) Ensure holiday source/day + warnings + decisions have enough data
-- ---------------------------------------------------------------------------
insert into public.holiday_calendar_sources (
  org_id, company_id, environment_type, is_demo,
  country_code, source_type, source_name, source_ref, is_enabled, last_synced_at
) values
  ('10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,'demo',true,'TW','official_api','TW Official Holidays','tw-gov-mock-v1',true,now()),
  ('10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,'production',false,'JP','official_api','JP Cabinet Office Holidays','jp-cao-mock-v1',true,now())
on conflict (org_id, company_id, country_code, source_type, source_name, environment_type)
do update set source_ref=excluded.source_ref,is_enabled=excluded.is_enabled,last_synced_at=excluded.last_synced_at,updated_at=now();

insert into public.holiday_calendar_days (
  org_id, company_id, environment_type, is_demo,
  country_code, holiday_date, holiday_name, holiday_category, is_paid_day_off, source_id
)
select
  d.org_id, d.company_id, d.environment_type, d.is_demo,
  d.country_code, d.holiday_date, d.holiday_name, d.holiday_category, d.is_paid_day_off, d.source_id
from (
  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    'demo'::text,
    true,
    'TW'::text,
    '2026-01-01'::date,
    '元旦'::text,
    'national'::text,
    true,
    (select id from public.holiday_calendar_sources where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and source_name='TW Official Holidays' limit 1)
  union all
  select '10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,'demo',true,'TW','2026-02-16','春節假期','national',true,(select id from public.holiday_calendar_sources where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and source_name='TW Official Holidays' limit 1)
  union all
  select '10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,'demo',true,'TW','2026-10-10','國慶日','national',true,(select id from public.holiday_calendar_sources where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and source_name='TW Official Holidays' limit 1)
  union all
  select '10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,'production',false,'JP','2026-01-01','元日','national',true,(select id from public.holiday_calendar_sources where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and source_name='JP Cabinet Office Holidays' limit 1)
  union all
  select '10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,'production',false,'JP','2026-02-11','建国記念の日','national',true,(select id from public.holiday_calendar_sources where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and source_name='JP Cabinet Office Holidays' limit 1)
  union all
  select '10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,'production',false,'JP','2026-11-03','文化の日','national',true,(select id from public.holiday_calendar_sources where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and source_name='JP Cabinet Office Holidays' limit 1)
) d(
  org_id, company_id, environment_type, is_demo,
  country_code, holiday_date, holiday_name, holiday_category, is_paid_day_off, source_id
)
where d.source_id is not null
on conflict (org_id, company_id, country_code, holiday_date, holiday_name, holiday_category, environment_type)
do update set is_paid_day_off=excluded.is_paid_day_off, source_id=excluded.source_id, updated_at=now();

insert into public.leave_compliance_warnings (
  id, org_id, company_id, policy_profile_id, environment_type, is_demo,
  warning_type, severity, title, message, country_code, related_rule_ref,
  is_resolved, resolved_at, resolved_by, resolution_note
) values
  ('d1f6c4e9-0000-4000-9000-000000000101'::uuid,'10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,(select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),'demo',true,'entitlement_rule_overlap','warning','特休規則有重疊區間','annual_leave 的歷年制與週年制區間需確認不重覆','TW','annual_leave',false,null,null,null),
  ('d1f6c4e9-0000-4000-9000-000000000102'::uuid,'10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,(select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),'demo',true,'holiday_sync_stale','info','假日日曆同步超過 30 天','建議重新同步官方假日日曆','TW','holiday_calendar_sources/TW',false,null,null,null),
  ('d1f6c4e9-0000-4000-9000-000000000201'::uuid,'10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,(select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),'production',false,'paid_leave_cap_check','warning','有給休暇上限確認','請確認 max_days_cap 是否符合最新公司規章','JP','paid_leave',false,null,null,null),
  ('d1f6c4e9-0000-4000-9000-000000000202'::uuid,'10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,(select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),'production',false,'holiday_policy_alignment','info','祝日と社内休日の整合チェック','official_calendar と shift 設定差異需每季檢查','JP','holiday_mode',false,null,null,null)
on conflict (id)
do update set severity=excluded.severity,title=excluded.title,message=excluded.message,is_resolved=excluded.is_resolved,resolved_at=excluded.resolved_at,resolved_by=excluded.resolved_by,resolution_note=excluded.resolution_note,updated_at=now();

insert into public.leave_policy_decisions (
  id, org_id, company_id, policy_profile_id, environment_type, is_demo,
  decision_type, decision_title, decision_note, approved_by, approved_at, attachment_ref
) values
  ('e2f6c4e9-0000-4000-9000-000000000101'::uuid,'10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,(select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000002'::uuid and company_id='20000000-0000-0000-0000-000000000002'::uuid and environment_type='demo' and country_code='TW' and policy_name='TW Leave Policy 2026 (Demo)' limit 1),'demo',true,'policy_approval','台灣 2026 假勤政策核准','核准 calendar_year + official_calendar 方案','998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid,now() - interval '7 days',null),
  ('e2f6c4e9-0000-4000-9000-000000000201'::uuid,'10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,(select id from public.leave_policy_profiles where org_id='10000000-0000-0000-0000-000000000001'::uuid and company_id='20000000-0000-0000-0000-000000000001'::uuid and environment_type='production' and country_code='JP' and policy_name='JP Leave Policy 2026' limit 1),'production',false,'policy_approval','Japan 2026 leave policy approval','Approved anniversary-year paid leave baseline','998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid,now() - interval '5 days',null)
on conflict (id)
do update set decision_title=excluded.decision_title,decision_note=excluded.decision_note,approved_by=excluded.approved_by,approved_at=excluded.approved_at,updated_at=now();

-- ---------------------------------------------------------------------------
-- E) HR display backfill: departments/positions/employees/onboarding/leave
-- ---------------------------------------------------------------------------
insert into public.departments (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  department_code, department_name, parent_department_id, manager_employee_id,
  sort_order, is_active
) values
  ('50000000-0000-0000-0000-000000000003'::uuid,'10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,null,'production',false,'OPS','Operations',null,null,30,true),
  ('51000000-0000-0000-0000-000000000103'::uuid,'10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,null,'demo',true,'D-OPS','Demo Operations',null,null,30,true)
on conflict (org_id, company_id, department_code, environment_type)
do update set department_name=excluded.department_name,sort_order=excluded.sort_order,is_active=excluded.is_active,updated_at=now();

insert into public.positions (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  position_code, position_name, job_level, is_managerial, is_active
) values
  ('60000000-0000-0000-0000-000000000003'::uuid,'10000000-0000-0000-0000-000000000001'::uuid,'20000000-0000-0000-0000-000000000001'::uuid,null,'production',false,'OPS-SP','Operations Specialist','L2',false,true),
  ('61000000-0000-0000-0000-000000000103'::uuid,'10000000-0000-0000-0000-000000000002'::uuid,'20000000-0000-0000-0000-000000000002'::uuid,null,'demo',true,'D-OPS-SP','Operations Specialist','L2',false,true)
on conflict (org_id, company_id, position_code, environment_type)
do update set position_name=excluded.position_name,job_level=excluded.job_level,is_managerial=excluded.is_managerial,is_active=excluded.is_active,updated_at=now();

insert into public.employees (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  employee_code, legal_name, preferred_name, display_name,
  family_name_local, given_name_local, full_name_local,
  family_name_latin, given_name_latin, full_name_latin,
  work_email, personal_email, mobile_phone,
  nationality_code, work_country_code, preferred_locale, timezone,
  department_id, position_id, manager_employee_id,
  employment_type, employment_status, hire_date, termination_date,
  gender_note, notes
) values
  -- Production additions (3)
  (
    '70000000-0000-0000-0000-000000000004'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    null,'production',false,
    'EMP-0004','Li Na',null,'Li Na',
    '李','娜','李娜',
    'Li','Na','Li Na',
    'li.na@lemma.local','li.na.personal@example.com','+886900000004',
    'CN','TW','zh-TW','Asia/Taipei',
    '50000000-0000-0000-0000-000000000002'::uuid,
    '60000000-0000-0000-0000-000000000002'::uuid,
    '70000000-0000-0000-0000-000000000002'::uuid,
    'full_time','active','2025-03-01',null,
    null,'Foreign worker case for HR display'
  ),
  (
    '70000000-0000-0000-0000-000000000005'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    null,'production',false,
    'EMP-0005','Takumi Ito',null,'Takumi Ito',
    '伊藤','匠','伊藤匠',
    'Ito','Takumi','Takumi Ito',
    'takumi.ito@lemma.local','takumi.ito.personal@example.com','+819011100005',
    'JP','JP','ja','Asia/Tokyo',
    '50000000-0000-0000-0000-000000000003'::uuid,
    '60000000-0000-0000-0000-000000000003'::uuid,
    '70000000-0000-0000-0000-000000000001'::uuid,
    'full_time','active','2025-06-15',null,
    null,'Ops specialist for staging list'
  ),
  (
    '70000000-0000-0000-0000-000000000006'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    null,'production',false,
    'EMP-0006','Sarah Lin',null,'Sarah Lin',
    '林','莎拉','林莎拉',
    'Lin','Sarah','Sarah Lin',
    'sarah.lin@lemma.local','sarah.lin.personal@example.com','+886900000006',
    'TW','TW','en','Asia/Taipei',
    '50000000-0000-0000-0000-000000000002'::uuid,
    '60000000-0000-0000-0000-000000000002'::uuid,
    '70000000-0000-0000-0000-000000000001'::uuid,
    'full_time','on_leave','2025-08-01',null,
    null,'On leave sample for status variety'
  ),

  -- Demo additions (2)
  (
    '71000000-0000-0000-0000-000000000105'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    null,'demo',true,
    'DEMO-005','陳柏宇',null,'陳柏宇',
    '陳','柏宇','陳柏宇',
    'Chen','Po-Yu','Po-Yu Chen',
    'demo005@lemma.local','demo005.personal@example.com','+886910000005',
    'TW','TW','zh-TW','Asia/Taipei',
    '51000000-0000-0000-0000-000000000101'::uuid,
    '61000000-0000-0000-0000-000000000102'::uuid,
    '71000000-0000-0000-0000-000000000101'::uuid,
    'full_time','active','2025-09-01',null,
    null,'Demo local employee'
  ),
  (
    '71000000-0000-0000-0000-000000000106'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    null,'demo',true,
    'DEMO-006','Nguyễn An',null,'Nguyễn An',
    'Nguyễn','An','Nguyễn An',
    'Nguyen','An','An Nguyen',
    'demo006@lemma.local','demo006.personal@example.com','+84901000006',
    'VN','TW','vi','Asia/Taipei',
    '51000000-0000-0000-0000-000000000103'::uuid,
    '61000000-0000-0000-0000-000000000103'::uuid,
    '71000000-0000-0000-0000-000000000102'::uuid,
    'contractor','active','2025-10-15',null,
    null,'Foreign worker sample (VN)'
  )
on conflict (org_id, company_id, employee_code, environment_type)
do update set
  legal_name = excluded.legal_name,
  preferred_name = excluded.preferred_name,
  display_name = excluded.display_name,
  family_name_local = excluded.family_name_local,
  given_name_local = excluded.given_name_local,
  full_name_local = excluded.full_name_local,
  family_name_latin = excluded.family_name_latin,
  given_name_latin = excluded.given_name_latin,
  full_name_latin = excluded.full_name_latin,
  work_email = excluded.work_email,
  mobile_phone = excluded.mobile_phone,
  nationality_code = excluded.nationality_code,
  work_country_code = excluded.work_country_code,
  preferred_locale = excluded.preferred_locale,
  timezone = excluded.timezone,
  department_id = excluded.department_id,
  position_id = excluded.position_id,
  manager_employee_id = excluded.manager_employee_id,
  employment_status = excluded.employment_status,
  hire_date = excluded.hire_date,
  notes = excluded.notes,
  updated_at = now();

-- Production onboarding variation
insert into public.employee_onboarding_invitations (
  id, org_id, company_id, employee_id, environment_type, is_demo,
  invitee_name, invitee_phone, invitee_email, preferred_language,
  expected_start_date, channel, token_hash, token_last4, expires_at,
  accepted_at, status, invited_by, reviewed_by, reviewed_at,
  created_by, updated_by
) values
  (
    '82000000-0000-0000-0000-000000000301'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    '70000000-0000-0000-0000-000000000004'::uuid,
    'production', false,
    'Li Na', '+886900000004', 'li.na@lemma.local', 'zh-TW',
    '2026-04-20', 'link',
    encode(digest('prod-invite-301','sha256'),'hex'), '0301', now() + interval '30 days',
    now() - interval '3 days', 'opened', '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,
    null, null,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid
  ),
  (
    '82000000-0000-0000-0000-000000000302'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    '70000000-0000-0000-0000-000000000005'::uuid,
    'production', false,
    'Takumi Ito', '+819011100005', 'takumi.ito@lemma.local', 'ja',
    '2026-04-25', 'line',
    encode(digest('prod-invite-302','sha256'),'hex'), '0302', now() + interval '30 days',
    now() - interval '2 days', 'submitted', '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid, now() - interval '1 day',
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid
  )
on conflict (id)
do update set
  status = excluded.status,
  accepted_at = excluded.accepted_at,
  reviewed_by = excluded.reviewed_by,
  reviewed_at = excluded.reviewed_at,
  updated_by = excluded.updated_by,
  updated_at = now();

insert into public.employee_onboarding_intake (
  id, org_id, company_id, employee_id, invitation_id, environment_type, is_demo,
  onboarding_status,
  family_name_local, given_name_local, full_name_local,
  family_name_latin, given_name_latin, full_name_latin,
  birth_date, phone, email, address,
  emergency_contact_name, emergency_contact_phone,
  nationality_code, identity_document_type, is_foreign_worker, notes,
  submitted_at, approved_at, approved_by,
  created_by, updated_by
) values
  (
    '83000000-0000-0000-0000-000000000302'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    '70000000-0000-0000-0000-000000000005'::uuid,
    '82000000-0000-0000-0000-000000000302'::uuid,
    'production', false,
    'submitted',
    '伊藤','匠','伊藤匠',
    'Ito','Takumi','Takumi Ito',
    '1993-04-12','+819011100005','takumi.ito@lemma.local','Tokyo, Japan',
    'Ito Keiko','+819099900000',
    'JP','passport',true,'Submitted by new hire',
    now() - interval '2 days', null, null,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid
  )
on conflict (invitation_id)
do update set
  onboarding_status = excluded.onboarding_status,
  submitted_at = excluded.submitted_at,
  updated_by = excluded.updated_by,
  updated_at = now();

-- Leave request cases mapped to policy leave types
insert into public.leave_requests (
  id, org_id, company_id, employee_id, environment_type, is_demo,
  leave_type, start_date, end_date, start_time, end_time,
  duration_hours, duration_days, reason,
  approver_user_id, approval_status, approved_at, rejected_at, rejection_reason,
  affects_payroll, has_attachment, attachment_count,
  created_by, updated_by
) values
  -- Production samples
  (
    '90000000-0000-0000-0000-000000000401'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    '70000000-0000-0000-0000-000000000004'::uuid,
    'production', false,
    'annual_leave','2026-04-15','2026-04-16',null,null,
    null,1.0,'Annual leave request for CN employee',
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,'approved',now() - interval '1 day',null,null,
    true,false,0,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid
  ),
  (
    '90000000-0000-0000-0000-000000000402'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    '70000000-0000-0000-0000-000000000005'::uuid,
    'production', false,
    'sick_leave','2026-04-18','2026-04-18',null,null,
    null,0.5,'Sick leave request (attachment expected)',
    null,'pending',null,null,null,
    true,true,1,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid,
    '43b32db9-4bfd-427b-b91c-ac268cbe148f'::uuid
  ),

  -- Demo samples
  (
    '90000000-0000-0000-0000-000000000403'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    '71000000-0000-0000-0000-000000000105'::uuid,
    'demo', true,
    'personal_leave','2026-04-20','2026-04-20',null,null,
    null,1.0,'Personal leave for demo employee',
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid,'approved',now() - interval '1 day',null,null,
    true,false,0,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid
  ),
  (
    '90000000-0000-0000-0000-000000000404'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    '71000000-0000-0000-0000-000000000106'::uuid,
    'demo', true,
    'unpaid_leave','2026-04-22','2026-04-23',null,null,
    null,2.0,'Unpaid leave for foreign contractor sample',
    null,'pending',null,null,null,
    true,false,0,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid
  )
on conflict (id)
do update set
  approval_status = excluded.approval_status,
  approver_user_id = excluded.approver_user_id,
  approved_at = excluded.approved_at,
  rejected_at = excluded.rejected_at,
  rejection_reason = excluded.rejection_reason,
  affects_payroll = excluded.affects_payroll,
  has_attachment = excluded.has_attachment,
  attachment_count = excluded.attachment_count,
  updated_by = excluded.updated_by,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- F) Normalize is_demo flags by environment_type to avoid scope read misses
-- ---------------------------------------------------------------------------
update public.leave_policy_profiles
set is_demo = (environment_type = 'demo'),
    updated_at = now()
where environment_type in ('demo', 'production');

update public.leave_types
set is_demo = (environment_type = 'demo'),
    updated_at = now()
where environment_type in ('demo', 'production');

update public.leave_entitlement_rules
set is_demo = (environment_type = 'demo'),
    updated_at = now()
where environment_type in ('demo', 'production');

update public.holiday_calendar_sources
set is_demo = (environment_type = 'demo'),
    updated_at = now()
where environment_type in ('demo', 'production');

update public.holiday_calendar_days
set is_demo = (environment_type = 'demo'),
    updated_at = now()
where environment_type in ('demo', 'production');

update public.leave_compliance_warnings
set is_demo = (environment_type = 'demo'),
    updated_at = now()
where environment_type in ('demo', 'production');

update public.leave_policy_decisions
set is_demo = (environment_type = 'demo'),
    updated_at = now()
where environment_type in ('demo', 'production');

-- ---------------------------------------------------------------------------
-- G) Canonicalize JP production policy profile (avoid duplicate profile rows)
-- ---------------------------------------------------------------------------
with prod_profiles as (
  select
    p.id,
    (
      coalesce((select count(*) from public.leave_types t where t.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_entitlement_rules r where r.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_compliance_warnings w where w.policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_policy_decisions d where d.policy_profile_id = p.id), 0)
    )::int as link_score
  from public.leave_policy_profiles p
  where p.org_id = '10000000-0000-0000-0000-000000000001'::uuid
    and p.company_id = '20000000-0000-0000-0000-000000000001'::uuid
    and p.environment_type = 'production'
    and p.policy_name = 'JP Leave Policy 2026'
),
canonical as (
  select id
  from prod_profiles
  order by link_score desc, id asc
  limit 1
),
stale as (
  select id
  from prod_profiles
  where id <> (select id from canonical)
)
delete from public.leave_types
where leave_policy_profile_id in (select id from stale);

with prod_profiles as (
  select
    p.id,
    (
      coalesce((select count(*) from public.leave_types t where t.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_entitlement_rules r where r.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_compliance_warnings w where w.policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_policy_decisions d where d.policy_profile_id = p.id), 0)
    )::int as link_score
  from public.leave_policy_profiles p
  where p.org_id = '10000000-0000-0000-0000-000000000001'::uuid
    and p.company_id = '20000000-0000-0000-0000-000000000001'::uuid
    and p.environment_type = 'production'
    and p.policy_name = 'JP Leave Policy 2026'
),
canonical as (
  select id
  from prod_profiles
  order by link_score desc, id asc
  limit 1
),
stale as (
  select id
  from prod_profiles
  where id <> (select id from canonical)
)
delete from public.leave_entitlement_rules
where leave_policy_profile_id in (select id from stale);

with prod_profiles as (
  select
    p.id,
    (
      coalesce((select count(*) from public.leave_types t where t.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_entitlement_rules r where r.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_compliance_warnings w where w.policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_policy_decisions d where d.policy_profile_id = p.id), 0)
    )::int as link_score
  from public.leave_policy_profiles p
  where p.org_id = '10000000-0000-0000-0000-000000000001'::uuid
    and p.company_id = '20000000-0000-0000-0000-000000000001'::uuid
    and p.environment_type = 'production'
    and p.policy_name = 'JP Leave Policy 2026'
),
canonical as (
  select id
  from prod_profiles
  order by link_score desc, id asc
  limit 1
),
stale as (
  select id
  from prod_profiles
  where id <> (select id from canonical)
)
delete from public.leave_compliance_warnings
where policy_profile_id in (select id from stale);

with prod_profiles as (
  select
    p.id,
    (
      coalesce((select count(*) from public.leave_types t where t.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_entitlement_rules r where r.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_compliance_warnings w where w.policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_policy_decisions d where d.policy_profile_id = p.id), 0)
    )::int as link_score
  from public.leave_policy_profiles p
  where p.org_id = '10000000-0000-0000-0000-000000000001'::uuid
    and p.company_id = '20000000-0000-0000-0000-000000000001'::uuid
    and p.environment_type = 'production'
    and p.policy_name = 'JP Leave Policy 2026'
),
canonical as (
  select id
  from prod_profiles
  order by link_score desc, id asc
  limit 1
),
stale as (
  select id
  from prod_profiles
  where id <> (select id from canonical)
)
delete from public.leave_policy_decisions
where policy_profile_id in (select id from stale);

with prod_profiles as (
  select
    p.id,
    (
      coalesce((select count(*) from public.leave_types t where t.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_entitlement_rules r where r.leave_policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_compliance_warnings w where w.policy_profile_id = p.id), 0) +
      coalesce((select count(*) from public.leave_policy_decisions d where d.policy_profile_id = p.id), 0)
    )::int as link_score
  from public.leave_policy_profiles p
  where p.org_id = '10000000-0000-0000-0000-000000000001'::uuid
    and p.company_id = '20000000-0000-0000-0000-000000000001'::uuid
    and p.environment_type = 'production'
    and p.policy_name = 'JP Leave Policy 2026'
),
canonical as (
  select id
  from prod_profiles
  order by link_score desc, id asc
  limit 1
),
stale as (
  select id
  from prod_profiles
  where id <> (select id from canonical)
)
delete from public.leave_policy_profiles
where id in (select id from stale);

update public.leave_policy_profiles p
set country_code = 'JP',
    is_demo = false,
    updated_at = now()
where p.org_id = '10000000-0000-0000-0000-000000000001'::uuid
  and p.company_id = '20000000-0000-0000-0000-000000000001'::uuid
  and p.environment_type = 'production'
  and p.policy_name = 'JP Leave Policy 2026';

-- ---------------------------------------------------------------------------
-- H) Country binding normalization for holiday/compliance read consistency
-- ---------------------------------------------------------------------------
update public.leave_policy_profiles
set allow_cross_country_holiday_merge = false,
    updated_at = now()
where allow_cross_country_holiday_merge is null;

with source_country as (
  select
    s.org_id,
    s.company_id,
    s.environment_type,
    min(s.country_code) as canonical_country_code,
    count(distinct s.country_code)::int as source_country_count
  from public.holiday_calendar_sources s
  where s.is_enabled = true
  group by s.org_id, s.company_id, s.environment_type
)
update public.leave_policy_profiles p
set country_code = sc.canonical_country_code,
    updated_at = now()
from source_country sc
where p.org_id = sc.org_id
  and p.company_id = sc.company_id
  and p.environment_type = sc.environment_type
  and coalesce(p.allow_cross_country_holiday_merge, false) = false
  and sc.source_country_count = 1
  and p.country_code is distinct from sc.canonical_country_code;

update public.holiday_calendar_days d
set country_code = s.country_code,
    updated_at = now()
from public.holiday_calendar_sources s
where d.source_id = s.id
  and d.country_code is distinct from s.country_code;

update public.leave_compliance_warnings w
set country_code = p.country_code,
    updated_at = now()
from public.leave_policy_profiles p
where p.id = w.policy_profile_id
  and w.country_code is distinct from p.country_code;

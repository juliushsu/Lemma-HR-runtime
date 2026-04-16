-- Leave Policy Engine minimal seed (staging only)
-- Cases:
-- 1) Taiwan company (demo scope)
-- 2) Japan company (production-like scope in staging DB)

-- ---------------------------------------------------------------------------
-- 1) Policy profiles
-- ---------------------------------------------------------------------------
insert into public.leave_policy_profiles (
  org_id,
  company_id,
  environment_type,
  is_demo,
  country_code,
  policy_name,
  effective_from,
  effective_to,
  leave_year_mode,
  holiday_mode,
  allow_cross_country_holiday_merge,
  payroll_policy_mode,
  compliance_warning_enabled,
  notes
) values
  (
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    'demo',
    true,
    'TW',
    'TW Leave Policy 2026 (Demo)',
    '2026-01-01',
    null,
    'calendar_year',
    'official_calendar',
    false,
    'strict',
    true,
    'Taiwan demo policy baseline'
  ),
  (
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    'production',
    false,
    'JP',
    'JP Leave Policy 2026',
    '2026-01-01',
    null,
    'anniversary_year',
    'official_calendar',
    false,
    'custom',
    true,
    'Japan baseline policy for paid leave'
  )
on conflict (org_id, company_id, country_code, policy_name, effective_from, environment_type)
do update set
  effective_to = excluded.effective_to,
  leave_year_mode = excluded.leave_year_mode,
  holiday_mode = excluded.holiday_mode,
  allow_cross_country_holiday_merge = excluded.allow_cross_country_holiday_merge,
  payroll_policy_mode = excluded.payroll_policy_mode,
  compliance_warning_enabled = excluded.compliance_warning_enabled,
  notes = excluded.notes,
  is_demo = excluded.is_demo,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 2) Leave types
-- ---------------------------------------------------------------------------
insert into public.leave_types (
  org_id,
  company_id,
  leave_policy_profile_id,
  environment_type,
  is_demo,
  leave_type_code,
  display_name,
  is_paid,
  affects_payroll,
  requires_attachment,
  requires_approval,
  sort_order,
  is_enabled
)
select
  x.org_id,
  x.company_id,
  x.leave_policy_profile_id,
  x.environment_type,
  x.is_demo,
  x.leave_type_code,
  x.display_name,
  x.is_paid,
  x.affects_payroll,
  x.requires_attachment,
  x.requires_approval,
  x.sort_order,
  x.is_enabled
from (
  -- Taiwan leave types
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ) as leave_policy_profile_id,
    'demo'::text as environment_type,
    true as is_demo,
    'annual_leave'::text as leave_type_code,
    '特休假'::text as display_name,
    true as is_paid,
    true as affects_payroll,
    false as requires_attachment,
    true as requires_approval,
    10 as sort_order,
    true as is_enabled

  union all

  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ),
    'demo',
    true,
    'sick_leave',
    '病假',
    true,
    true,
    true,
    true,
    20,
    true

  union all

  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ),
    'demo',
    true,
    'personal_leave',
    '事假',
    false,
    true,
    false,
    true,
    30,
    true

  union all

  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ),
    'demo',
    true,
    'unpaid_leave',
    '無薪假',
    false,
    true,
    false,
    true,
    40,
    true

  union all

  -- Japan leave types
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
    'production',
    false,
    'annual_leave',
    '年次休暇',
    true,
    true,
    false,
    true,
    10,
    true

  union all

  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
    'production',
    false,
    'paid_leave',
    '有給休暇',
    true,
    true,
    false,
    true,
    20,
    true

  union all

  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
    'production',
    false,
    'sick_leave',
    '病気休暇',
    false,
    true,
    true,
    true,
    30,
    true

  union all

  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
    'production',
    false,
    'unpaid_leave',
    '無給休暇',
    false,
    true,
    false,
    true,
    40,
    true
) x
where x.leave_policy_profile_id is not null
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
-- 3) Entitlement rules
-- ---------------------------------------------------------------------------
insert into public.leave_entitlement_rules (
  org_id,
  company_id,
  leave_policy_profile_id,
  environment_type,
  is_demo,
  leave_type_code,
  accrual_mode,
  tenure_months_from,
  tenure_months_to,
  granted_days,
  max_days_cap,
  carry_forward_mode,
  carry_forward_days,
  effective_from,
  effective_to
)
select
  x.org_id,
  x.company_id,
  x.leave_policy_profile_id,
  x.environment_type,
  x.is_demo,
  x.leave_type_code,
  x.accrual_mode,
  x.tenure_months_from,
  x.tenure_months_to,
  x.granted_days,
  x.max_days_cap,
  x.carry_forward_mode,
  x.carry_forward_days,
  x.effective_from,
  x.effective_to
from (
  -- Taiwan calendar + anniversary examples
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ) as leave_policy_profile_id,
    'demo'::text as environment_type,
    true as is_demo,
    'annual_leave'::text as leave_type_code,
    'calendar'::text as accrual_mode,
    12::int as tenure_months_from,
    23::int as tenure_months_to,
    7.0::numeric as granted_days,
    30.0::numeric as max_days_cap,
    'limited'::text as carry_forward_mode,
    5.0::numeric as carry_forward_days,
    '2026-01-01'::date as effective_from,
    null::date as effective_to

  union all

  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ),
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

  -- Japan paid leave anniversary rule
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
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
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
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
) x
where x.leave_policy_profile_id is not null
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
-- 4) Holiday sources
-- ---------------------------------------------------------------------------
insert into public.holiday_calendar_sources (
  org_id,
  company_id,
  environment_type,
  is_demo,
  country_code,
  source_type,
  source_name,
  source_ref,
  is_enabled,
  last_synced_at
) values
  (
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    'demo',
    true,
    'TW',
    'official_api',
    'TW Official Holidays',
    'tw-gov-mock-v1',
    true,
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    'production',
    false,
    'JP',
    'official_api',
    'JP Cabinet Office Holidays',
    'jp-cao-mock-v1',
    true,
    now()
  )
on conflict (org_id, company_id, country_code, source_type, source_name, environment_type)
do update set
  source_ref = excluded.source_ref,
  is_enabled = excluded.is_enabled,
  last_synced_at = excluded.last_synced_at,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 5) Holiday days (>=3 each country)
-- ---------------------------------------------------------------------------
insert into public.holiday_calendar_days (
  org_id,
  company_id,
  environment_type,
  is_demo,
  country_code,
  holiday_date,
  holiday_name,
  holiday_category,
  is_paid_day_off,
  source_id
)
select
  x.org_id,
  x.company_id,
  x.environment_type,
  x.is_demo,
  x.country_code,
  x.holiday_date,
  x.holiday_name,
  x.holiday_category,
  x.is_paid_day_off,
  x.source_id
from (
  -- Taiwan
  select
    '10000000-0000-0000-0000-000000000002'::uuid as org_id,
    '20000000-0000-0000-0000-000000000002'::uuid as company_id,
    'demo'::text as environment_type,
    true as is_demo,
    'TW'::text as country_code,
    '2026-01-01'::date as holiday_date,
    '元旦'::text as holiday_name,
    'national'::text as holiday_category,
    true as is_paid_day_off,
    (
      select s.id from public.holiday_calendar_sources s
      where s.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and s.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and s.environment_type='demo'
        and s.country_code='TW'
        and s.source_name='TW Official Holidays'
      limit 1
    ) as source_id

  union all

  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    'demo',
    true,
    'TW',
    '2026-02-16',
    '春節假期',
    'national',
    true,
    (
      select s.id from public.holiday_calendar_sources s
      where s.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and s.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and s.environment_type='demo'
        and s.country_code='TW'
        and s.source_name='TW Official Holidays'
      limit 1
    )

  union all

  select
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    'demo',
    true,
    'TW',
    '2026-10-10',
    '國慶日',
    'national',
    true,
    (
      select s.id from public.holiday_calendar_sources s
      where s.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and s.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and s.environment_type='demo'
        and s.country_code='TW'
        and s.source_name='TW Official Holidays'
      limit 1
    )

  union all

  -- Japan
  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    'production',
    false,
    'JP',
    '2026-01-01',
    '元日',
    'national',
    true,
    (
      select s.id from public.holiday_calendar_sources s
      where s.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and s.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and s.environment_type='production'
        and s.country_code='JP'
        and s.source_name='JP Cabinet Office Holidays'
      limit 1
    )

  union all

  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    'production',
    false,
    'JP',
    '2026-02-11',
    '建国記念の日',
    'national',
    true,
    (
      select s.id from public.holiday_calendar_sources s
      where s.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and s.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and s.environment_type='production'
        and s.country_code='JP'
        and s.source_name='JP Cabinet Office Holidays'
      limit 1
    )

  union all

  select
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    'production',
    false,
    'JP',
    '2026-11-03',
    '文化の日',
    'national',
    true,
    (
      select s.id from public.holiday_calendar_sources s
      where s.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and s.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and s.environment_type='production'
        and s.country_code='JP'
        and s.source_name='JP Cabinet Office Holidays'
      limit 1
    )
) x
where x.source_id is not null
on conflict (org_id, company_id, country_code, holiday_date, holiday_name, holiday_category, environment_type)
do update set
  is_paid_day_off = excluded.is_paid_day_off,
  source_id = excluded.source_id,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 6) Compliance warnings (>=2 each country)
-- ---------------------------------------------------------------------------
insert into public.leave_compliance_warnings (
  id,
  org_id,
  company_id,
  policy_profile_id,
  environment_type,
  is_demo,
  warning_type,
  severity,
  title,
  message,
  country_code,
  related_rule_ref,
  is_resolved,
  resolved_at,
  resolved_by,
  resolution_note
) values
  (
    'd1f6c4e9-0000-4000-9000-000000000101'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ),
    'demo',
    true,
    'entitlement_rule_overlap',
    'warning',
    '特休規則有重疊區間',
    'annual_leave 的歷年制與週年制區間需確認不重覆',
    'TW',
    'annual_leave',
    false,
    null,
    null,
    null
  ),
  (
    'd1f6c4e9-0000-4000-9000-000000000102'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ),
    'demo',
    true,
    'holiday_sync_stale',
    'info',
    '假日日曆同步超過 30 天',
    '建議重新同步官方假日日曆',
    'TW',
    'holiday_calendar_sources/TW',
    false,
    null,
    null,
    null
  ),
  (
    'd1f6c4e9-0000-4000-9000-000000000201'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
    'production',
    false,
    'paid_leave_cap_check',
    'warning',
    '有給休暇上限確認',
    '請確認 max_days_cap 是否符合最新公司規章',
    'JP',
    'paid_leave',
    false,
    null,
    null,
    null
  ),
  (
    'd1f6c4e9-0000-4000-9000-000000000202'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
    'production',
    false,
    'holiday_policy_alignment',
    'info',
    '祝日と社内休日の整合チェック',
    'official_calendar と shift 設定差異需每季檢查',
    'JP',
    'holiday_mode',
    false,
    null,
    null,
    null
  )
on conflict (id)
do update set
  warning_type = excluded.warning_type,
  severity = excluded.severity,
  title = excluded.title,
  message = excluded.message,
  country_code = excluded.country_code,
  related_rule_ref = excluded.related_rule_ref,
  is_resolved = excluded.is_resolved,
  resolved_at = excluded.resolved_at,
  resolved_by = excluded.resolved_by,
  resolution_note = excluded.resolution_note,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 7) Policy decisions
-- ---------------------------------------------------------------------------
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
  attachment_ref
) values
  (
    'e2f6c4e9-0000-4000-9000-000000000101'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000002'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000002'::uuid
        and p.environment_type='demo'
        and p.country_code='TW'
        and p.policy_name='TW Leave Policy 2026 (Demo)'
      limit 1
    ),
    'demo',
    true,
    'policy_approval',
    '台灣 2026 假勤政策核准',
    '核准 calendar_year + official_calendar 方案',
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid,
    now() - interval '7 days',
    null
  ),
  (
    'e2f6c4e9-0000-4000-9000-000000000201'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000001'::uuid,
    (
      select p.id from public.leave_policy_profiles p
      where p.org_id='10000000-0000-0000-0000-000000000001'::uuid
        and p.company_id='20000000-0000-0000-0000-000000000001'::uuid
        and p.environment_type='production'
        and p.country_code='JP'
        and p.policy_name='JP Leave Policy 2026'
      limit 1
    ),
    'production',
    false,
    'policy_approval',
    'Japan 2026 leave policy approval',
    'Approved anniversary-year paid leave baseline',
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid,
    now() - interval '5 days',
    null
  )
on conflict (id)
do update set
  decision_type = excluded.decision_type,
  decision_title = excluded.decision_title,
  decision_note = excluded.decision_note,
  approved_by = excluded.approved_by,
  approved_at = excluded.approved_at,
  attachment_ref = excluded.attachment_ref,
  updated_at = now();

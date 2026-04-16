-- HR+ MVP v1 minimal seed
-- Scope: only foundation + employee/org chart/attendance chain
-- Safe to run multiple times (uses ON CONFLICT on primary keys / unique keys).

begin;

-- Fixed IDs
-- org/company/branch
-- org:      10000000-0000-0000-0000-000000000001
-- company:  20000000-0000-0000-0000-000000000001
-- branch:   30000000-0000-0000-0000-000000000001

-- users
-- admin:    40000000-0000-0000-0000-000000000001
-- manager:  40000000-0000-0000-0000-000000000002
-- viewer:   40000000-0000-0000-0000-000000000003

-- departments
-- dpt_hq:   50000000-0000-0000-0000-000000000001
-- dpt_hr:   50000000-0000-0000-0000-000000000002

-- positions
-- pos_hrm:  60000000-0000-0000-0000-000000000001
-- pos_hrs:  60000000-0000-0000-0000-000000000002

-- employees
-- emp_1:    70000000-0000-0000-0000-000000000001
-- emp_2:    70000000-0000-0000-0000-000000000002
-- emp_3:    70000000-0000-0000-0000-000000000003

-- attendance policy/profile/log
-- policy_1: 80000000-0000-0000-0000-000000000001

insert into organizations (
  id, name, locale_default, environment_type, is_demo, created_by, updated_by
) values (
  '10000000-0000-0000-0000-000000000001', 'Lemma HR+ Org', 'en', 'production', false, null, null
)
on conflict (id) do update
set name = excluded.name,
    locale_default = excluded.locale_default,
    environment_type = excluded.environment_type,
    is_demo = excluded.is_demo,
    updated_at = now();

insert into companies (
  id, org_id, name, locale_default, environment_type, is_demo, created_by, updated_by
) values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'Lemma HR+ Company',
  'en',
  'production',
  false,
  null,
  null
)
on conflict (id) do update
set org_id = excluded.org_id,
    name = excluded.name,
    locale_default = excluded.locale_default,
    environment_type = excluded.environment_type,
    is_demo = excluded.is_demo,
    updated_at = now();

insert into branches (
  id, org_id, company_id, name, environment_type, is_demo, created_by, updated_by
) values (
  '30000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'Taipei HQ',
  'production',
  false,
  null,
  null
)
on conflict (id) do update
set org_id = excluded.org_id,
    company_id = excluded.company_id,
    name = excluded.name,
    environment_type = excluded.environment_type,
    is_demo = excluded.is_demo,
    updated_at = now();

insert into users (
  id, email, display_name, locale_preference, timezone, currency, environment_type, is_demo, created_by, updated_by
) values
(
  '40000000-0000-0000-0000-000000000001',
  'admin@lemma-hr.local',
  'Admin User',
  'en',
  'Asia/Taipei',
  'TWD',
  'production',
  false,
  null,
  null
),
(
  '40000000-0000-0000-0000-000000000002',
  'manager@lemma-hr.local',
  'Manager User',
  'en',
  'Asia/Taipei',
  'TWD',
  'production',
  false,
  null,
  null
),
(
  '40000000-0000-0000-0000-000000000003',
  'viewer@lemma-hr.local',
  'Viewer User',
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

insert into memberships (
  id, user_id, org_id, company_id, branch_id, role, scope_type, environment_type, is_demo, created_by, updated_by
) values
(
  '41000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  null,
  'admin',
  'company',
  'production',
  false,
  null,
  null
),
(
  '41000000-0000-0000-0000-000000000002',
  '40000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'manager',
  'branch',
  'production',
  false,
  null,
  null
),
(
  '41000000-0000-0000-0000-000000000003',
  '40000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  null,
  'viewer',
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

insert into departments (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  department_code, department_name, parent_department_id, manager_employee_id, sort_order, is_active,
  created_by, updated_by
) values
(
  '50000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  null,
  'production',
  false,
  'HQ',
  'Headquarters',
  null,
  null,
  100,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '50000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  'HR',
  'Human Resources',
  '50000000-0000-0000-0000-000000000001',
  null,
  110,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set department_code = excluded.department_code,
    department_name = excluded.department_name,
    parent_department_id = excluded.parent_department_id,
    manager_employee_id = excluded.manager_employee_id,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    updated_at = now();

insert into positions (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  position_code, position_name, job_level, is_managerial, is_active,
  created_by, updated_by
) values
(
  '60000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  null,
  'production',
  false,
  'HRM',
  'HR Manager',
  'L3',
  true,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '60000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  'HRS',
  'HR Specialist',
  'L2',
  false,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set position_code = excluded.position_code,
    position_name = excluded.position_name,
    job_level = excluded.job_level,
    is_managerial = excluded.is_managerial,
    is_active = excluded.is_active,
    updated_at = now();

insert into employees (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  employee_code, legal_name, preferred_name, display_name,
  family_name_local, given_name_local, full_name_local,
  family_name_latin, given_name_latin, full_name_latin,
  work_email, personal_email, mobile_phone,
  nationality_code, work_country_code, preferred_locale, timezone,
  department_id, position_id, manager_employee_id,
  employment_type, employment_status, hire_date, termination_date,
  gender_note, notes,
  created_by, updated_by
) values
(
  '70000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  'EMP-0001',
  'Helen Chen',
  'Helen',
  'Helen Chen',
  '陳',
  '海倫',
  '陳海倫',
  'Chen',
  'Helen',
  'Helen Chen',
  'helen@lemma-hr.local',
  null,
  '+886900000001',
  'TW',
  'TW',
  'en',
  'Asia/Taipei',
  '50000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000001',
  null,
  'full_time',
  'active',
  date '2025-01-01',
  null,
  null,
  'Org manager',
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '70000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  'EMP-0002',
  'Ken Sato',
  'Ken',
  'Ken Sato',
  '佐藤',
  '健',
  '佐藤健',
  'Sato',
  'Ken',
  'Ken Sato',
  'ken@lemma-hr.local',
  null,
  '+886900000002',
  'JP',
  'TW',
  'ja',
  'Asia/Taipei',
  '50000000-0000-0000-0000-000000000002',
  '60000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001',
  'full_time',
  'active',
  date '2025-02-01',
  null,
  null,
  'Branch manager',
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '70000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  'EMP-0003',
  'Mike Wang',
  'Mike',
  'Mike Wang',
  '王',
  '麥克',
  '王麥克',
  'Wang',
  'Mike',
  'Mike Wang',
  'mike@lemma-hr.local',
  null,
  '+886900000003',
  'TW',
  'TW',
  'en',
  'Asia/Taipei',
  '50000000-0000-0000-0000-000000000002',
  '60000000-0000-0000-0000-000000000002',
  '70000000-0000-0000-0000-000000000002',
  'full_time',
  'active',
  date '2025-03-01',
  null,
  null,
  'HR specialist',
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set employee_code = excluded.employee_code,
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
    department_id = excluded.department_id,
    position_id = excluded.position_id,
    manager_employee_id = excluded.manager_employee_id,
    employment_status = excluded.employment_status,
    updated_at = now();

update departments
set manager_employee_id = case
  when id = '50000000-0000-0000-0000-000000000001' then '70000000-0000-0000-0000-000000000001'::uuid
  when id = '50000000-0000-0000-0000-000000000002' then '70000000-0000-0000-0000-000000000002'::uuid
  else manager_employee_id
end,
updated_at = now()
where id in (
  '50000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000002'
);

insert into employee_assignments (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  employee_id, department_id, position_id, manager_employee_id,
  assignment_type, effective_from, effective_to, is_current,
  created_by, updated_by
) values
(
  '71000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000001',
  null,
  'primary',
  date '2025-01-01',
  null,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '71000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000002',
  '50000000-0000-0000-0000-000000000002',
  '60000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001',
  'primary',
  date '2025-02-01',
  null,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '71000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000003',
  '50000000-0000-0000-0000-000000000002',
  '60000000-0000-0000-0000-000000000002',
  '70000000-0000-0000-0000-000000000002',
  'primary',
  date '2025-03-01',
  null,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set employee_id = excluded.employee_id,
    department_id = excluded.department_id,
    position_id = excluded.position_id,
    manager_employee_id = excluded.manager_employee_id,
    assignment_type = excluded.assignment_type,
    effective_from = excluded.effective_from,
    effective_to = excluded.effective_to,
    is_current = excluded.is_current,
    updated_at = now();

insert into attendance_policies (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  policy_code, policy_name, timezone,
  standard_check_in_time, standard_check_out_time,
  late_grace_minutes, early_leave_grace_minutes, is_active,
  created_by, updated_by
) values (
  '80000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  'STD-TPE',
  'Taipei Standard',
  'Asia/Taipei',
  time '09:00:00',
  time '18:00:00',
  10,
  10,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set policy_code = excluded.policy_code,
    policy_name = excluded.policy_name,
    timezone = excluded.timezone,
    standard_check_in_time = excluded.standard_check_in_time,
    standard_check_out_time = excluded.standard_check_out_time,
    late_grace_minutes = excluded.late_grace_minutes,
    early_leave_grace_minutes = excluded.early_leave_grace_minutes,
    is_active = excluded.is_active,
    updated_at = now();

insert into employee_attendance_profiles (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  employee_id, attendance_policy_id, effective_from, effective_to, is_current,
  created_by, updated_by
) values
(
  '81000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000001',
  date '2025-01-01',
  null,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '81000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000002',
  '80000000-0000-0000-0000-000000000001',
  date '2025-02-01',
  null,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '81000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000003',
  '80000000-0000-0000-0000-000000000001',
  date '2025-03-01',
  null,
  true,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set attendance_policy_id = excluded.attendance_policy_id,
    effective_from = excluded.effective_from,
    effective_to = excluded.effective_to,
    is_current = excluded.is_current,
    updated_at = now();

insert into attendance_logs (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  employee_id, attendance_date, check_type, checked_at,
  source_type, source_ref,
  gps_lat, gps_lng, geo_distance_m, is_within_geo_range,
  status_code, is_valid, is_adjusted, note,
  created_by, updated_by
) values
(
  '82000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000001',
  date '2026-04-01',
  'check_in',
  timestamptz '2026-04-01 08:58:00+08',
  'mobile',
  null,
  25.0339680,
  121.5644680,
  20.00,
  true,
  'normal',
  true,
  false,
  null,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '82000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000001',
  date '2026-04-01',
  'check_out',
  timestamptz '2026-04-01 18:03:00+08',
  'mobile',
  null,
  25.0339680,
  121.5644680,
  22.00,
  true,
  'normal',
  true,
  false,
  null,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '82000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000002',
  date '2026-04-01',
  'check_in',
  timestamptz '2026-04-01 09:14:00+08',
  'mobile',
  null,
  25.0339680,
  121.5644680,
  35.00,
  false,
  'late',
  true,
  false,
  'Traffic delay',
  '40000000-0000-0000-0000-000000000002',
  '40000000-0000-0000-0000-000000000002'
),
(
  '82000000-0000-0000-0000-000000000004',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000002',
  date '2026-04-01',
  'check_out',
  timestamptz '2026-04-01 18:02:00+08',
  'mobile',
  null,
  25.0339680,
  121.5644680,
  30.00,
  true,
  'normal',
  true,
  false,
  null,
  '40000000-0000-0000-0000-000000000002',
  '40000000-0000-0000-0000-000000000002'
),
(
  '82000000-0000-0000-0000-000000000005',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000003',
  date '2026-04-01',
  'check_in',
  timestamptz '2026-04-01 08:57:00+08',
  'line_liff',
  'liff_event_001',
  25.0339680,
  121.5644680,
  18.00,
  true,
  'normal',
  true,
  false,
  null,
  '40000000-0000-0000-0000-000000000003',
  '40000000-0000-0000-0000-000000000003'
),
(
  '82000000-0000-0000-0000-000000000006',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000003',
  date '2026-04-01',
  'check_out',
  timestamptz '2026-04-01 17:42:00+08',
  'line_liff',
  'liff_event_002',
  25.0339680,
  121.5644680,
  19.00,
  true,
  'early_leave',
  true,
  false,
  'Left early for appointment',
  '40000000-0000-0000-0000-000000000003',
  '40000000-0000-0000-0000-000000000003'
),
(
  '82000000-0000-0000-0000-000000000007',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000003',
  date '2026-04-02',
  'check_in',
  timestamptz '2026-04-02 09:30:00+08',
  'manual',
  'manual_fix_001',
  null,
  null,
  null,
  null,
  'manual_adjusted',
  true,
  true,
  'Backfilled by HR admin',
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
),
(
  '82000000-0000-0000-0000-000000000008',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '70000000-0000-0000-0000-000000000002',
  date '2026-04-02',
  'check_in',
  timestamptz '2026-04-02 09:05:00+08',
  'import',
  'csv_batch_20260402',
  null,
  null,
  null,
  null,
  'invalid',
  false,
  true,
  'Duplicated import record invalidated',
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set attendance_date = excluded.attendance_date,
    check_type = excluded.check_type,
    checked_at = excluded.checked_at,
    source_type = excluded.source_type,
    status_code = excluded.status_code,
    is_valid = excluded.is_valid,
    is_adjusted = excluded.is_adjusted,
    note = excluded.note,
    updated_at = now();

insert into attendance_adjustments (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  attendance_log_id, employee_id,
  adjustment_type, requested_value, original_value, reason,
  approval_status, approved_by, approved_at,
  created_by, updated_by
) values (
  '83000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'production',
  false,
  '82000000-0000-0000-0000-000000000003',
  '70000000-0000-0000-0000-000000000002',
  'time_correction',
  '{"checked_at":"2026-04-01T09:07:00+08:00"}'::jsonb,
  '{"checked_at":"2026-04-01T09:14:00+08:00"}'::jsonb,
  'Employee submitted proof',
  'pending',
  null,
  null,
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001'
)
on conflict (id) do update
set requested_value = excluded.requested_value,
    original_value = excluded.original_value,
    reason = excluded.reason,
    approval_status = excluded.approval_status,
    updated_at = now();

commit;

-- Post-seed quick checks
-- select count(*) from organizations;                -- 1
-- select count(*) from companies;                    -- 1
-- select count(*) from branches;                     -- 1
-- select count(*) from users;                        -- 3
-- select count(*) from memberships;                  -- 3
-- select count(*) from departments;                  -- 2
-- select count(*) from positions;                    -- 2
-- select count(*) from employees;                    -- 3
-- select count(*) from attendance_policies;          -- 1
-- select count(*) from employee_attendance_profiles; -- 3
-- select count(*) from attendance_logs;              -- 8

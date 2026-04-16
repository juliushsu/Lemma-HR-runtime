-- STAGING ONLY sandbox visibility seed for team@lemmaofficial.com
-- Scope: Lemma Test Org/Company
-- org_id: 10000000-0000-0000-0000-0000000000aa
-- company_id: 20000000-0000-0000-0000-0000000000aa

DO $$
DECLARE
  v_org uuid := '10000000-0000-0000-0000-0000000000aa';
  v_company uuid := '20000000-0000-0000-0000-0000000000aa';
  v_env text := 'sandbox';
  v_actor uuid;

  v_dept_exec uuid;
  v_dept_hr uuid;
  v_dept_eng uuid;
  v_dept_ops uuid;
  v_dept_sales uuid;

  v_pos_ceo uuid;
  v_pos_hr_mgr uuid;
  v_pos_eng_mgr uuid;
  v_pos_sales_sup uuid;
  v_pos_hr_spec uuid;
  v_pos_engineer uuid;
  v_pos_ops_coord uuid;

  v_emp_0001 uuid;
  v_emp_0002 uuid;
  v_emp_0003 uuid;
  v_emp_0004 uuid;
  v_emp_0005 uuid;
  v_emp_0006 uuid;
  v_emp_0007 uuid;
  v_emp_0008 uuid;
  v_emp_0009 uuid;
  v_emp_0010 uuid;
  v_emp_0011 uuid;
BEGIN
  SELECT id INTO v_actor
  FROM public.users
  WHERE lower(email) = 'team@lemmaofficial.com'
  LIMIT 1;

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'team@lemmaofficial.com not found in public.users';
  END IF;

  INSERT INTO public.departments (
    org_id, company_id, branch_id, environment_type, is_demo,
    department_code, department_name, parent_department_id, manager_employee_id,
    sort_order, is_active, created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env, false, 'SBX-EXEC',  'Sandbox Executive', NULL, NULL, 10, true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-HR',    'Sandbox People Ops', NULL, NULL, 20, true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-ENG',   'Sandbox Engineering', NULL, NULL, 30, true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-OPS',   'Sandbox Operations', NULL, NULL, 40, true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-SALES', 'Sandbox Sales', NULL, NULL, 50, true, v_actor, v_actor)
  ON CONFLICT (org_id, company_id, department_code, environment_type)
  DO UPDATE SET
    department_name = EXCLUDED.department_name,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active,
    updated_at = now(),
    updated_by = EXCLUDED.updated_by;

  SELECT id INTO v_dept_exec FROM public.departments WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND department_code='SBX-EXEC';
  SELECT id INTO v_dept_hr FROM public.departments WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND department_code='SBX-HR';
  SELECT id INTO v_dept_eng FROM public.departments WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND department_code='SBX-ENG';
  SELECT id INTO v_dept_ops FROM public.departments WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND department_code='SBX-OPS';
  SELECT id INTO v_dept_sales FROM public.departments WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND department_code='SBX-SALES';

  INSERT INTO public.positions (
    org_id, company_id, branch_id, environment_type, is_demo,
    position_code, position_name, job_level, is_managerial, is_active,
    created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env, false, 'SBX-CEO',      'Chief Executive Officer', 'L7', true,  true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-HR-MGR',   'People Operations Manager', 'L5', true,  true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-ENG-MGR',  'Engineering Manager', 'L5', true,  true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-SALES-SUP','Sales Supervisor', 'L4', true,  true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-HR-SPEC',  'People Operations Specialist', 'L3', false, true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-ENG-IC',   'Software Engineer', 'L3', false, true, v_actor, v_actor),
    (v_org, v_company, NULL, v_env, false, 'SBX-OPS-COORD','Operations Coordinator', 'L2', false, true, v_actor, v_actor)
  ON CONFLICT (org_id, company_id, position_code, environment_type)
  DO UPDATE SET
    position_name = EXCLUDED.position_name,
    job_level = EXCLUDED.job_level,
    is_managerial = EXCLUDED.is_managerial,
    is_active = EXCLUDED.is_active,
    updated_at = now(),
    updated_by = EXCLUDED.updated_by;

  SELECT id INTO v_pos_ceo FROM public.positions WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND position_code='SBX-CEO';
  SELECT id INTO v_pos_hr_mgr FROM public.positions WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND position_code='SBX-HR-MGR';
  SELECT id INTO v_pos_eng_mgr FROM public.positions WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND position_code='SBX-ENG-MGR';
  SELECT id INTO v_pos_sales_sup FROM public.positions WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND position_code='SBX-SALES-SUP';
  SELECT id INTO v_pos_hr_spec FROM public.positions WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND position_code='SBX-HR-SPEC';
  SELECT id INTO v_pos_engineer FROM public.positions WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND position_code='SBX-ENG-IC';
  SELECT id INTO v_pos_ops_coord FROM public.positions WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND position_code='SBX-OPS-COORD';

  INSERT INTO public.employees (
    org_id, company_id, branch_id, environment_type, is_demo, is_test,
    employee_code, legal_name, preferred_name, display_name,
    work_email, personal_email, mobile_phone,
    nationality_code, work_country_code, preferred_locale, timezone,
    department_id, position_id, manager_employee_id,
    employment_type, employment_status, hire_date, termination_date,
    notes,
    family_name_local, given_name_local, full_name_local,
    family_name_latin, given_name_latin, full_name_latin,
    gender, birth_date,
    emergency_contact_name, emergency_contact_phone,
    created_by, updated_by
  ) VALUES (
    v_org, v_company, NULL, v_env, false, true,
    'SBX-EMP-0001', '王明志', '明志', '王明志',
    'sbx.ceo@lemma.local', 'mingzhi@example.test', '+886900000001',
    'TW', 'TW', 'zh-TW', 'Asia/Taipei',
    v_dept_exec, v_pos_ceo, NULL,
    'full_time', 'active', DATE '2022-01-10', NULL,
    'Sandbox seed manager root',
    '王', '明志', '王明志',
    'Wang', 'Mingzhi', 'Wang Mingzhi',
    'male', DATE '1986-04-12',
    '王美玲', '+886900100001',
    v_actor, v_actor
  )
  ON CONFLICT (org_id, company_id, employee_code, environment_type)
  DO UPDATE SET
    legal_name = EXCLUDED.legal_name,
    preferred_name = EXCLUDED.preferred_name,
    display_name = EXCLUDED.display_name,
    work_email = EXCLUDED.work_email,
    personal_email = EXCLUDED.personal_email,
    mobile_phone = EXCLUDED.mobile_phone,
    nationality_code = EXCLUDED.nationality_code,
    work_country_code = EXCLUDED.work_country_code,
    preferred_locale = EXCLUDED.preferred_locale,
    timezone = EXCLUDED.timezone,
    department_id = EXCLUDED.department_id,
    position_id = EXCLUDED.position_id,
    manager_employee_id = EXCLUDED.manager_employee_id,
    employment_type = EXCLUDED.employment_type,
    employment_status = EXCLUDED.employment_status,
    hire_date = EXCLUDED.hire_date,
    termination_date = EXCLUDED.termination_date,
    notes = EXCLUDED.notes,
    family_name_local = EXCLUDED.family_name_local,
    given_name_local = EXCLUDED.given_name_local,
    full_name_local = EXCLUDED.full_name_local,
    family_name_latin = EXCLUDED.family_name_latin,
    given_name_latin = EXCLUDED.given_name_latin,
    full_name_latin = EXCLUDED.full_name_latin,
    gender = EXCLUDED.gender,
    birth_date = EXCLUDED.birth_date,
    emergency_contact_name = EXCLUDED.emergency_contact_name,
    emergency_contact_phone = EXCLUDED.emergency_contact_phone,
    is_test = true,
    updated_at = now(),
    updated_by = EXCLUDED.updated_by
  RETURNING id INTO v_emp_0001;

  INSERT INTO public.employees (
    org_id, company_id, branch_id, environment_type, is_demo, is_test,
    employee_code, legal_name, preferred_name, display_name,
    work_email, personal_email, mobile_phone,
    nationality_code, work_country_code, preferred_locale, timezone,
    department_id, position_id, manager_employee_id,
    employment_type, employment_status, hire_date,
    notes,
    family_name_local, given_name_local, full_name_local,
    family_name_latin, given_name_latin, full_name_latin,
    gender, birth_date,
    emergency_contact_name, emergency_contact_phone,
    created_by, updated_by
  ) VALUES
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0002', '林雅婷', '雅婷', '林雅婷', 'sbx.hr.manager@lemma.local', 'yating@example.test', '+886900000002', 'TW', 'TW', 'zh-TW', 'Asia/Taipei', v_dept_hr, v_pos_hr_mgr, v_emp_0001, 'full_time', 'active', DATE '2023-03-15', 'Sandbox HR manager', '林', '雅婷', '林雅婷', 'Lin', 'Yating', 'Lin Yating', 'female', DATE '1990-02-03', '林志明', '+886900100002', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0003', '陳柏宇', '柏宇', '陳柏宇', 'sbx.eng.manager@lemma.local', 'boyu@example.test', '+886900000003', 'TW', 'TW', 'zh-TW', 'Asia/Taipei', v_dept_eng, v_pos_eng_mgr, v_emp_0001, 'full_time', 'active', DATE '2023-06-01', 'Sandbox engineering manager', '陳', '柏宇', '陳柏宇', 'Chen', 'Boyu', 'Chen Boyu', 'male', DATE '1989-08-22', '陳月華', '+886900100003', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0004', '佐藤 健', '健', '佐藤 健', 'sbx.sales.supervisor@lemma.local', 'sato@example.test', '+819000000004', 'JP', 'TW', 'ja', 'Asia/Tokyo', v_dept_sales, v_pos_sales_sup, v_emp_0001, 'full_time', 'active', DATE '2024-01-18', 'Sandbox sales supervisor', '佐藤', '健', '佐藤 健', 'Sato', 'Ken', 'Ken Sato', 'male', DATE '1992-11-09', '佐藤 美香', '+819000100004', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0005', '吳佳穎', '佳穎', '吳佳穎', 'sbx.hr.specialist@lemma.local', 'jiaying@example.test', '+886900000005', 'TW', 'TW', 'zh-TW', 'Asia/Taipei', v_dept_hr, v_pos_hr_spec, v_emp_0002, 'full_time', 'active', current_date - 7, 'Recent hire for insight', '吳', '佳穎', '吳佳穎', 'Wu', 'Jiaying', 'Wu Jiaying', 'female', DATE '1996-05-17', '吳建國', '+886900100005', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0006', '李俊豪', '俊豪', '李俊豪', 'sbx.eng.ic1@lemma.local', 'junhao@example.test', '+886900000006', 'TW', 'TW', 'zh-TW', 'Asia/Taipei', v_dept_eng, v_pos_engineer, v_emp_0003, 'full_time', 'active', current_date - 14, 'Recent hire for insight', '李', '俊豪', '李俊豪', 'Li', 'Junhao', 'Li Junhao', 'male', DATE '1997-09-28', '李淑芬', '+886900100006', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0007', '김민수', '민수', '김민수', 'sbx.sales.cs1@lemma.local', 'minsu@example.test', '+821000000007', 'KR', 'TW', 'ko', 'Asia/Seoul', v_dept_sales, v_pos_ops_coord, v_emp_0004, 'full_time', 'active', DATE '2024-08-12', 'Korean specialist', '김', '민수', '김민수', 'Kim', 'Minsu', 'Minsu Kim', 'male', DATE '1994-12-01', '김지영', '+821000100007', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0008', 'Nguyen Thi Lan', 'Lan', 'Nguyen Thi Lan', 'sbx.ops.coord1@lemma.local', 'lan@example.test', '+849000000008', 'VN', 'TW', 'vi', 'Asia/Ho_Chi_Minh', v_dept_ops, v_pos_ops_coord, v_emp_0001, 'full_time', 'active', DATE '2024-09-02', 'Vietnamese staff', 'Nguyen', 'Thi Lan', 'Nguyen Thi Lan', 'Nguyen', 'Thi Lan', 'Nguyen Thi Lan', 'female', DATE '1995-07-21', 'Nguyen Van Nam', '+849000100008', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0009', 'Sandbox Missing Local', 'Missing Local', 'Sandbox Missing Local', 'sbx.incomplete.local@lemma.local', 'incomplete1@example.test', '+886900000009', 'TW', 'TW', 'en', 'Asia/Taipei', v_dept_eng, v_pos_engineer, v_emp_0003, 'full_time', 'active', DATE '2024-10-10', 'Incomplete: missing full_name_local', NULL, NULL, NULL, 'Sandbox', 'Missing Local', 'Sandbox Missing Local', 'prefer_not_to_say', NULL, NULL, NULL, v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0010', 'Sandbox Missing Department', 'Missing Dept', 'Sandbox Missing Department', 'sbx.incomplete.dept@lemma.local', 'incomplete2@example.test', '+886900000010', 'TW', 'TW', 'en', 'Asia/Taipei', NULL, v_pos_hr_spec, v_emp_0002, 'full_time', 'active', DATE '2024-10-18', 'Incomplete: missing department', 'Sandbox', 'Missing Department', 'Sandbox Missing Department', 'Sandbox', 'Missing Department', 'Sandbox Missing Department', 'female', DATE '1993-06-11', 'Test Contact', '+886900100010', v_actor, v_actor),
  (v_org, v_company, NULL, v_env, false, true, 'SBX-EMP-0011', 'Sandbox Former Employee', 'Former', 'Sandbox Former Employee', 'sbx.former@lemma.local', 'former@example.test', '+886900000011', 'TW', 'TW', 'en', 'Asia/Taipei', v_dept_ops, NULL, v_emp_0001, 'full_time', 'terminated', DATE '2023-01-05', 'Former employee for departures + incomplete', 'Sandbox', 'Former Employee', 'Sandbox Former Employee', 'Sandbox', 'Former Employee', 'Sandbox Former Employee', 'male', DATE '1991-03-19', 'Test Contact 2', '+886900100011', v_actor, v_actor)
  ON CONFLICT (org_id, company_id, employee_code, environment_type)
  DO UPDATE SET
    legal_name = EXCLUDED.legal_name,
    preferred_name = EXCLUDED.preferred_name,
    display_name = EXCLUDED.display_name,
    work_email = EXCLUDED.work_email,
    personal_email = EXCLUDED.personal_email,
    mobile_phone = EXCLUDED.mobile_phone,
    nationality_code = EXCLUDED.nationality_code,
    work_country_code = EXCLUDED.work_country_code,
    preferred_locale = EXCLUDED.preferred_locale,
    timezone = EXCLUDED.timezone,
    department_id = EXCLUDED.department_id,
    position_id = EXCLUDED.position_id,
    manager_employee_id = EXCLUDED.manager_employee_id,
    employment_type = EXCLUDED.employment_type,
    employment_status = EXCLUDED.employment_status,
    hire_date = EXCLUDED.hire_date,
    notes = EXCLUDED.notes,
    family_name_local = EXCLUDED.family_name_local,
    given_name_local = EXCLUDED.given_name_local,
    full_name_local = EXCLUDED.full_name_local,
    family_name_latin = EXCLUDED.family_name_latin,
    given_name_latin = EXCLUDED.given_name_latin,
    full_name_latin = EXCLUDED.full_name_latin,
    gender = EXCLUDED.gender,
    birth_date = EXCLUDED.birth_date,
    emergency_contact_name = EXCLUDED.emergency_contact_name,
    emergency_contact_phone = EXCLUDED.emergency_contact_phone,
    is_test = true,
    updated_at = now(),
    updated_by = EXCLUDED.updated_by;

  SELECT id INTO v_emp_0002 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0002';
  SELECT id INTO v_emp_0003 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0003';
  SELECT id INTO v_emp_0004 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0004';
  SELECT id INTO v_emp_0005 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0005';
  SELECT id INTO v_emp_0006 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0006';
  SELECT id INTO v_emp_0007 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0007';
  SELECT id INTO v_emp_0008 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0008';
  SELECT id INTO v_emp_0009 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0009';
  SELECT id INTO v_emp_0010 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0010';
  SELECT id INTO v_emp_0011 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type=v_env AND employee_code='SBX-EMP-0011';

  UPDATE public.employees
  SET manager_employee_id = CASE employee_code
    WHEN 'SBX-EMP-0001' THEN NULL
    WHEN 'SBX-EMP-0002' THEN v_emp_0001
    WHEN 'SBX-EMP-0003' THEN v_emp_0001
    WHEN 'SBX-EMP-0004' THEN v_emp_0001
    WHEN 'SBX-EMP-0005' THEN v_emp_0002
    WHEN 'SBX-EMP-0006' THEN v_emp_0003
    WHEN 'SBX-EMP-0007' THEN v_emp_0004
    WHEN 'SBX-EMP-0008' THEN v_emp_0001
    WHEN 'SBX-EMP-0009' THEN v_emp_0003
    WHEN 'SBX-EMP-0010' THEN v_emp_0002
    WHEN 'SBX-EMP-0011' THEN v_emp_0001
    ELSE manager_employee_id
  END,
  updated_at = now(),
  updated_by = v_actor
  WHERE org_id = v_org
    AND company_id = v_company
    AND environment_type = v_env
    AND employee_code like 'SBX-EMP-%';

  UPDATE public.departments
  SET manager_employee_id = CASE department_code
    WHEN 'SBX-EXEC' THEN v_emp_0001
    WHEN 'SBX-HR' THEN v_emp_0002
    WHEN 'SBX-ENG' THEN v_emp_0003
    WHEN 'SBX-SALES' THEN v_emp_0004
    WHEN 'SBX-OPS' THEN v_emp_0008
    ELSE manager_employee_id
  END,
  updated_at = now(),
  updated_by = v_actor
  WHERE org_id = v_org
    AND company_id = v_company
    AND environment_type = v_env
    AND department_code in ('SBX-EXEC','SBX-HR','SBX-ENG','SBX-SALES','SBX-OPS');

  INSERT INTO public.employee_language_skills (
    org_id, company_id, employee_id, environment_type, is_demo,
    language_code, proficiency_level, skill_type, is_primary,
    created_by, updated_by
  ) VALUES
    (v_org, v_company, v_emp_0001, v_env, false, 'zh', 'native',       'spoken', true,  v_actor, v_actor),
    (v_org, v_company, v_emp_0001, v_env, false, 'en', 'business',     'spoken', false, v_actor, v_actor),
    (v_org, v_company, v_emp_0004, v_env, false, 'ja', 'native',       'spoken', true,  v_actor, v_actor),
    (v_org, v_company, v_emp_0007, v_env, false, 'ko', 'native',       'spoken', true,  v_actor, v_actor),
    (v_org, v_company, v_emp_0008, v_env, false, 'vi', 'native',       'spoken', true,  v_actor, v_actor),
    (v_org, v_company, v_emp_0008, v_env, false, 'en', 'conversational','spoken', false, v_actor, v_actor),
    (v_org, v_company, v_emp_0006, v_env, false, 'en', 'business',     'spoken', true,  v_actor, v_actor)
  ON CONFLICT (employee_id, language_code, skill_type, environment_type)
  DO UPDATE SET
    proficiency_level = EXCLUDED.proficiency_level,
    is_primary = EXCLUDED.is_primary,
    updated_at = now(),
    updated_by = EXCLUDED.updated_by;
END
$$;

-- STAGING ONLY: Portal narrative seed data for sandbox org/company
-- Goal: build a coherent storyline across overview / people / org / ai / compliance / notifications.
-- org_id: 10000000-0000-0000-0000-0000000000aa
-- company_id: 20000000-0000-0000-0000-0000000000aa

DO $$
DECLARE
  v_org uuid := '10000000-0000-0000-0000-0000000000aa';
  v_company uuid := '20000000-0000-0000-0000-0000000000aa';
  v_env text := 'sandbox';
  v_actor uuid;

  v_emp_0001 uuid;
  v_emp_0002 uuid;
  v_emp_0003 uuid;
  v_emp_0004 uuid;
  v_emp_0005 uuid;
  v_emp_0006 uuid;
  v_emp_0007 uuid;
  v_emp_0008 uuid;
  v_emp_0010 uuid;

  v_doc_001 uuid;
  v_doc_002 uuid;
  v_doc_003 uuid;
  v_case_001 uuid;
  v_case_002 uuid;

  d1 date := current_date - 1;
  d2 date := current_date - 2;
  d3 date := current_date - 3;
  d4 date := current_date - 4;
BEGIN
  SELECT id INTO v_actor
  FROM public.users
  WHERE lower(email) = 'team@lemmaofficial.com'
  LIMIT 1;

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'team@lemmaofficial.com not found in public.users';
  END IF;

  SELECT id INTO v_emp_0001 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0001';
  SELECT id INTO v_emp_0002 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0002';
  SELECT id INTO v_emp_0003 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0003';
  SELECT id INTO v_emp_0004 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0004';
  SELECT id INTO v_emp_0005 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0005';
  SELECT id INTO v_emp_0006 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0006';
  SELECT id INTO v_emp_0007 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0007';
  SELECT id INTO v_emp_0008 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0008';
  SELECT id INTO v_emp_0010 FROM public.employees WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND employee_code='SBX-EMP-0010';

  -- 1) Make employment type distribution narrative (not all full-time)
  UPDATE public.employees
  SET employment_type = CASE employee_code
      WHEN 'SBX-EMP-0007' THEN 'part_time'
      WHEN 'SBX-EMP-0010' THEN 'contractor'
      ELSE employment_type
    END,
    updated_at = now(),
    updated_by = v_actor
  WHERE org_id = v_org
    AND company_id = v_company
    AND environment_type::text = v_env
    AND employee_code IN ('SBX-EMP-0007','SBX-EMP-0010');

  -- 2) Attendance storyline for this month (mix of normal/late/missing)
  DELETE FROM public.attendance_logs
  WHERE org_id = v_org
    AND company_id = v_company
    AND environment_type::text = v_env
    AND source_ref like 'sbx_story_attendance_%';

  INSERT INTO public.attendance_logs (
    org_id, company_id, branch_id, environment_type, is_demo,
    employee_id, attendance_date, check_type, checked_at,
    source_type, source_ref,
    status_code, is_valid, is_adjusted, note,
    created_by, updated_by
  ) VALUES
    -- Day d1
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0001, d1, 'check_in',  (d1::text || ' 09:03:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d1_e1_in',  'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0001, d1, 'check_out', (d1::text || ' 18:12:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d1_e1_out', 'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0003, d1, 'check_in',  (d1::text || ' 09:40:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d1_e3_in',  'late',   true, false, 'Traffic delay', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0003, d1, 'check_out', (d1::text || ' 18:18:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d1_e3_out', 'late',   true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0005, d1, 'check_in',  (d1::text || ' 08:58:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d1_e5_in',  'normal', true, false, 'New hire onboarding week', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0005, d1, 'check_out', (d1::text || ' 17:47:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d1_e5_out', 'normal', true, false, 'Story seed', v_actor, v_actor),

    -- Day d2
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0002, d2, 'check_in',  (d2::text || ' 09:05:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d2_e2_in',  'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0002, d2, 'check_out', (d2::text || ' 18:03:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d2_e2_out', 'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0006, d2, 'check_in',  (d2::text || ' 09:01:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d2_e6_in',  'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0006, d2, 'check_out', (d2::text || ' 18:09:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d2_e6_out', 'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0007, d2, 'check_in',  (d2::text || ' 13:03:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d2_e7_in',  'normal', true, false, 'Part-time afternoon shift', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0007, d2, 'check_out', (d2::text || ' 17:35:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d2_e7_out', 'normal', true, false, 'Story seed', v_actor, v_actor),

    -- Day d3
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0004, d3, 'check_in',  (d3::text || ' 09:02:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d3_e4_in',  'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0004, d3, 'check_out', (d3::text || ' 18:21:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d3_e4_out', 'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0008, d3, 'check_in',  (d3::text || ' 09:11:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d3_e8_in',  'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0008, d3, 'check_out', (d3::text || ' 18:16:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d3_e8_out', 'normal', true, false, 'Story seed', v_actor, v_actor),

    -- Day d4 (one missing signal)
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0001, d4, 'check_in',  (d4::text || ' 09:00:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d4_e1_in',  'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0001, d4, 'check_out', (d4::text || ' 18:00:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d4_e1_out', 'normal', true, false, 'Story seed', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_emp_0010, d4, 'check_in',  (d4::text || ' 09:33:00+00')::timestamptz, 'manual', 'sbx_story_attendance_d4_e10_in', 'missing', true, false, 'Contractor forgot check-out', v_actor, v_actor);

  -- 3) Legal docs storyline (expiring + pending signoff)
  DELETE FROM public.legal_case_documents WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND legal_document_id IN (
    SELECT id FROM public.legal_documents WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND document_code like 'SBX-STORY-DOC-%'
  );
  DELETE FROM public.legal_document_tags WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND legal_document_id IN (
    SELECT id FROM public.legal_documents WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND document_code like 'SBX-STORY-DOC-%'
  );
  DELETE FROM public.legal_document_versions WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND legal_document_id IN (
    SELECT id FROM public.legal_documents WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND document_code like 'SBX-STORY-DOC-%'
  );
  DELETE FROM public.legal_documents
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND document_code like 'SBX-STORY-DOC-%';

  INSERT INTO public.legal_documents (
    org_id, company_id, branch_id, environment_type, is_demo,
    document_code, title, document_type,
    governing_law_code, jurisdiction_note, counterparty_name, counterparty_type,
    effective_date, expiry_date, auto_renewal_date, signing_status,
    source_module, source_record_id,
    created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'SBX-STORY-DOC-001', 'Cloud Vendor MSA 2026', 'procurement_contract', 'TW', 'Taipei District Court', 'Acme Cloud Ltd.', 'vendor', current_date - 330, current_date + 12, current_date + 7, 'signed', NULL, NULL, v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'SBX-STORY-DOC-002', 'Data Processing Addendum', 'nda', 'TW', 'Taipei District Court', 'Acme Cloud Ltd.', 'vendor', current_date - 120, current_date + 5, NULL, 'pending', NULL, NULL, v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'SBX-STORY-DOC-003', 'Employee Handbook 2026', 'policy', 'TW', 'Internal Policy', 'Internal', 'internal', current_date - 45, current_date + 180, NULL, 'signed', NULL, NULL, v_actor, v_actor);

  SELECT id INTO v_doc_001
  FROM public.legal_documents
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND document_code='SBX-STORY-DOC-001'
  LIMIT 1;
  SELECT id INTO v_doc_002
  FROM public.legal_documents
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND document_code='SBX-STORY-DOC-002'
  LIMIT 1;
  SELECT id INTO v_doc_003
  FROM public.legal_documents
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND document_code='SBX-STORY-DOC-003'
  LIMIT 1;

  DELETE FROM public.legal_document_tags
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env
    AND legal_document_id IN (v_doc_001, v_doc_002, v_doc_003);

  INSERT INTO public.legal_document_tags (
    org_id, company_id, branch_id, environment_type, is_demo,
    legal_document_id, tag, created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_doc_001, 'renewal_watch', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_doc_002, 'pending_signoff', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_doc_003, 'policy', v_actor, v_actor);

  -- 4) Legal case storyline
  DELETE FROM public.legal_case_events
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env
    AND legal_case_id IN (SELECT id FROM public.legal_cases WHERE case_code like 'SBX-STORY-CASE-%' AND org_id=v_org AND company_id=v_company AND environment_type::text = v_env);
  DELETE FROM public.legal_cases
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND case_code like 'SBX-STORY-CASE-%';

  INSERT INTO public.legal_cases (
    org_id, company_id, branch_id, environment_type, is_demo,
    case_code, case_type, title, status, governing_law_code,
    forum_note, risk_level, summary, owner_user_id,
    created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'SBX-STORY-CASE-001', 'labor_dispute', 'Overtime policy clarification', 'under_review', 'TW', 'Labor Bureau mediation', 'warning', 'Pending review of overtime evidence pack', v_actor, v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'SBX-STORY-CASE-002', 'contract_breach', 'Vendor clause negotiation', 'closed', 'TW', 'Commercial court', 'info', 'Closed after clause amendment accepted', v_actor, v_actor, v_actor);

  SELECT id INTO v_case_001
  FROM public.legal_cases
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND case_code='SBX-STORY-CASE-001'
  LIMIT 1;
  SELECT id INTO v_case_002
  FROM public.legal_cases
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env AND case_code='SBX-STORY-CASE-002'
  LIMIT 1;

  INSERT INTO public.legal_case_events (
    org_id, company_id, branch_id, environment_type, is_demo,
    legal_case_id, event_date, event_type, description, source_document_id,
    created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_case_001, current_date - 2, 'hearing_scheduled', 'Mediation hearing scheduled next week', v_doc_002, v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_case_002, current_date - 10, 'case_closed', 'Negotiation completed and case closed', v_doc_001, v_actor, v_actor);

  DELETE FROM public.legal_case_documents
  WHERE org_id=v_org AND company_id=v_company AND environment_type::text = v_env
    AND legal_case_id IN (v_case_001, v_case_002);

  INSERT INTO public.legal_case_documents (
    org_id, company_id, branch_id, environment_type, is_demo,
    legal_case_id, legal_document_id, relationship_type,
    created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_case_001, v_doc_002, 'evidence', v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, v_case_002, v_doc_001, 'reference', v_actor, v_actor);

  -- 5) Compliance signals storyline
  DELETE FROM public.leave_compliance_warnings
  WHERE org_id=v_org
    AND company_id=v_company
    AND environment_type::text = v_env
    AND warning_type like 'portal_story_%';

  INSERT INTO public.leave_compliance_warnings (
    org_id, company_id, policy_profile_id, environment_type, is_demo,
    warning_type, severity, title, message, country_code, related_rule_ref,
    is_resolved, resolved_at, resolved_by, resolution_note,
    created_by, updated_by
  ) VALUES
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'portal_story_document_expiry', 'critical', 'Critical document nearing expiry', 'Data Processing Addendum expires in 5 days and is still pending signoff.', 'TW', 'LEGAL_DOC_EXPIRY_30D', false, NULL, NULL, NULL, v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'portal_story_attendance_missing', 'warning', 'Attendance integrity warning', 'One contractor record has missing checkout this week.', 'TW', 'ATTENDANCE_LOG_COMPLETENESS', false, NULL, NULL, NULL, v_actor, v_actor),
    (v_org, v_company, NULL, v_env::public.environment_type, false, 'portal_story_resolved_example', 'info', 'Resolved policy warning', 'Historical warning kept as resolved sample.', 'TW', 'LEAVE_POLICY_NOTICE', true, now() - interval '2 days', v_actor, 'Resolved after policy update', v_actor, v_actor);

END
$$;

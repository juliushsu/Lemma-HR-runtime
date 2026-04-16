-- LC+ Phase 1 demo legal seed (minimal showcase dataset)
-- Scope guard:
-- - org_id = 10000000-0000-0000-0000-000000000002
-- - company_id = 20000000-0000-0000-0000-000000000002
-- - environment_type = 'demo'
-- - is_demo = true
-- Safe to run repeatedly (fixed IDs + ON CONFLICT).

begin;

do $$
declare
  v_org_id uuid := '10000000-0000-0000-0000-000000000002';
  v_company_id uuid := '20000000-0000-0000-0000-000000000002';
  v_branch_id uuid;
  v_actor_user_id uuid;
  v_employee_id uuid;
  v_env environment_type := 'demo';
  v_is_demo boolean := true;

  -- legal_documents
  v_doc_emp_id uuid := 'b0000000-0000-0000-0000-000000000101';
  v_doc_po_id uuid  := 'b0000000-0000-0000-0000-000000000102';
  v_doc_nda_id uuid := 'b0000000-0000-0000-0000-000000000103';

  -- legal_document_versions
  v_ver_emp_v1_id uuid := 'b1000000-0000-0000-0000-000000000101';
  v_ver_po_v1_id uuid  := 'b1000000-0000-0000-0000-000000000102';
  v_ver_nda_v1_id uuid := 'b1000000-0000-0000-0000-000000000103';
  v_ver_nda_v2_id uuid := 'b1000000-0000-0000-0000-000000000104';

  -- legal_cases
  v_case_labor_id uuid := 'b2000000-0000-0000-0000-000000000101';
  v_case_proc_id uuid  := 'b2000000-0000-0000-0000-000000000102';

  -- legal_case_events
  v_evt_labor_1 uuid := 'b3000000-0000-0000-0000-000000000101';
  v_evt_labor_2 uuid := 'b3000000-0000-0000-0000-000000000102';
  v_evt_labor_3 uuid := 'b3000000-0000-0000-0000-000000000103';
  v_evt_proc_1 uuid  := 'b3000000-0000-0000-0000-000000000104';
  v_evt_proc_2 uuid  := 'b3000000-0000-0000-0000-000000000105';
begin
  -- strict demo scope check
  if not exists (
    select 1
    from public.companies c
    where c.id = v_company_id
      and c.org_id = v_org_id
      and c.environment_type = 'demo'
      and c.is_demo = true
  ) then
    raise exception 'LC+ demo seed failed: demo org/company not found or not demo scope';
  end if;

  select b.id
  into v_branch_id
  from public.branches b
  where b.org_id = v_org_id
    and b.company_id = v_company_id
    and b.environment_type = 'demo'
    and b.is_demo = true
  order by b.created_at asc
  limit 1;

  select u.id
  into v_actor_user_id
  from public.users u
  where u.email = 'demo.admin@lemma.local'
  limit 1;

  if v_actor_user_id is null then
    select m.user_id
    into v_actor_user_id
    from public.memberships m
    where m.org_id = v_org_id
      and m.company_id = v_company_id
      and m.environment_type = 'demo'
      and m.is_demo = true
    order by m.created_at asc
    limit 1;
  end if;

  select e.id
  into v_employee_id
  from public.employees e
  where e.org_id = v_org_id
    and e.company_id = v_company_id
    and e.environment_type = 'demo'
    and e.is_demo = true
  order by e.created_at asc
  limit 1;

  -- legal_documents (3): employment / procurement / nda
  insert into public.legal_documents (
    id, org_id, company_id, branch_id, environment_type, is_demo,
    document_code, title, document_type,
    counterparty_name, counterparty_type,
    governing_law_code, jurisdiction_note,
    effective_date, expiry_date, signing_status,
    source_module, source_record_id,
    created_by, updated_by
  ) values
  (
    v_doc_emp_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    'D-EMP-001', 'Demo Employment Contract - Lin Mei', 'employment_contract',
    'Lin Mei', 'employee',
    'TW', 'Taipei District Court',
    date '2026-01-01', date '2027-01-01', 'signed',
    'hr_plus', v_employee_id,
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_doc_po_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    'D-PO-001', 'Demo Procurement Agreement - Acme Supplies', 'procurement_contract',
    'Acme Supplies Ltd.', 'vendor',
    'TW', 'Taipei District Court',
    date '2026-02-01', date '2027-02-01', 'signed',
    'po_plus', null,
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_doc_nda_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    'D-NDA-001', 'Demo Mutual NDA - Project Sparrow', 'nda',
    'Sparrow Partner Inc.', 'vendor',
    'TW', 'Taipei District Court',
    date '2026-02-15', date '2028-02-15', 'signed',
    'lc_plus', null,
    v_actor_user_id, v_actor_user_id
  )
  on conflict (id) do update
  set title = excluded.title,
      document_type = excluded.document_type,
      counterparty_name = excluded.counterparty_name,
      counterparty_type = excluded.counterparty_type,
      governing_law_code = excluded.governing_law_code,
      jurisdiction_note = excluded.jurisdiction_note,
      effective_date = excluded.effective_date,
      expiry_date = excluded.expiry_date,
      signing_status = excluded.signing_status,
      source_module = excluded.source_module,
      source_record_id = excluded.source_record_id,
      updated_by = excluded.updated_by,
      updated_at = now();

  -- legal_document_versions
  -- each document >=1 version; NDA has 2 versions for history
  insert into public.legal_document_versions (
    id, org_id, company_id, branch_id, environment_type, is_demo,
    legal_document_id, version_no,
    storage_path, file_name, file_ext, mime_type, file_size_bytes,
    uploaded_by, uploaded_at, is_current, parsed_status,
    created_by, updated_by
  ) values
  (
    v_ver_emp_v1_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_doc_emp_id, 1,
    concat(v_org_id::text, '/', v_company_id::text, '/demo/', v_doc_emp_id::text, '/v1/demo_employment_contract_linmei.pdf'),
    'demo_employment_contract_linmei.pdf', 'pdf', 'application/pdf', 121000,
    v_actor_user_id, now(), true, 'pending',
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_ver_po_v1_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_doc_po_id, 1,
    concat(v_org_id::text, '/', v_company_id::text, '/demo/', v_doc_po_id::text, '/v1/demo_procurement_agreement_acme.pdf'),
    'demo_procurement_agreement_acme.pdf', 'pdf', 'application/pdf', 97500,
    v_actor_user_id, now(), true, 'pending',
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_ver_nda_v1_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_doc_nda_id, 1,
    concat(v_org_id::text, '/', v_company_id::text, '/demo/', v_doc_nda_id::text, '/v1/demo_mutual_nda_sparrow_v1.pdf'),
    'demo_mutual_nda_sparrow_v1.pdf', 'pdf', 'application/pdf', 80320,
    v_actor_user_id, now(), false, 'pending',
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_ver_nda_v2_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_doc_nda_id, 2,
    concat(v_org_id::text, '/', v_company_id::text, '/demo/', v_doc_nda_id::text, '/v2/demo_mutual_nda_sparrow_v2.pdf'),
    'demo_mutual_nda_sparrow_v2.pdf', 'pdf', 'application/pdf', 82640,
    v_actor_user_id, now(), true, 'pending',
    v_actor_user_id, v_actor_user_id
  )
  on conflict (id) do update
  set legal_document_id = excluded.legal_document_id,
      version_no = excluded.version_no,
      storage_path = excluded.storage_path,
      file_name = excluded.file_name,
      file_ext = excluded.file_ext,
      mime_type = excluded.mime_type,
      file_size_bytes = excluded.file_size_bytes,
      uploaded_by = excluded.uploaded_by,
      is_current = excluded.is_current,
      parsed_status = excluded.parsed_status,
      updated_by = excluded.updated_by,
      updated_at = now();

  -- guarantee one current version per document
  update public.legal_document_versions
  set is_current = false,
      updated_by = v_actor_user_id,
      updated_at = now()
  where legal_document_id in (v_doc_emp_id, v_doc_po_id, v_doc_nda_id)
    and id not in (v_ver_emp_v1_id, v_ver_po_v1_id, v_ver_nda_v2_id);

  update public.legal_documents
  set current_version_id = case
      when id = v_doc_emp_id then v_ver_emp_v1_id
      when id = v_doc_po_id then v_ver_po_v1_id
      when id = v_doc_nda_id then v_ver_nda_v2_id
      else current_version_id
    end,
    updated_by = v_actor_user_id,
    updated_at = now()
  where id in (v_doc_emp_id, v_doc_po_id, v_doc_nda_id);

  -- legal_document_tags (1~2 each)
  insert into public.legal_document_tags (
    org_id, company_id, branch_id, environment_type, is_demo,
    legal_document_id, tag, created_by, updated_by
  ) values
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_doc_emp_id, 'HR', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_doc_emp_id, 'Active', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_doc_po_id, 'Vendor', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_doc_po_id, 'Active', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_doc_nda_id, 'Confidential', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_doc_nda_id, 'Active', v_actor_user_id, v_actor_user_id)
  on conflict (legal_document_id, tag) do update
  set updated_at = now(),
      updated_by = excluded.updated_by;

  -- legal_cases (2): labor/procurement disputes
  insert into public.legal_cases (
    id, org_id, company_id, branch_id, environment_type, is_demo,
    case_code, case_type, title, status,
    governing_law_code, forum_note, risk_level, summary, owner_user_id,
    created_by, updated_by
  ) values
  (
    v_case_labor_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    'D-CASE-LBR-001', 'labor_dispute', 'Demo Overtime Compensation Dispute', 'under_review',
    'TW', 'Taipei District Court', 'medium',
    'Employee disputes overtime compensation calculations for Q1.',
    v_actor_user_id,
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_case_proc_id, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    'D-CASE-PRC-001', 'procurement_dispute', 'Demo Delivery Penalty Dispute', 'open',
    'TW', 'Taipei District Court', 'medium',
    'Vendor disputes liquidated damages for delayed delivery milestones.',
    v_actor_user_id,
    v_actor_user_id, v_actor_user_id
  )
  on conflict (id) do update
  set title = excluded.title,
      status = excluded.status,
      governing_law_code = excluded.governing_law_code,
      forum_note = excluded.forum_note,
      risk_level = excluded.risk_level,
      summary = excluded.summary,
      owner_user_id = excluded.owner_user_id,
      updated_by = excluded.updated_by,
      updated_at = now();

  -- legal_case_documents (each case links 1~2 documents)
  insert into public.legal_case_documents (
    org_id, company_id, branch_id, environment_type, is_demo,
    legal_case_id, legal_document_id, relationship_type,
    created_by, updated_by
  ) values
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_case_labor_id, v_doc_emp_id, 'primary_contract', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_case_labor_id, v_doc_nda_id, 'supporting_evidence', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_case_proc_id, v_doc_po_id, 'primary_contract', v_actor_user_id, v_actor_user_id),
  (v_org_id, v_company_id, v_branch_id, v_env, v_is_demo, v_case_proc_id, v_doc_nda_id, 'supporting_evidence', v_actor_user_id, v_actor_user_id)
  on conflict (legal_case_id, legal_document_id) do update
  set relationship_type = excluded.relationship_type,
      updated_at = now(),
      updated_by = excluded.updated_by;

  -- legal_case_events (2~3 events each case)
  insert into public.legal_case_events (
    id, org_id, company_id, branch_id, environment_type, is_demo,
    legal_case_id, event_date, event_type, description, source_document_id,
    created_by, updated_by
  ) values
  (
    v_evt_labor_1, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_case_labor_id, date '2026-03-10', 'complaint_received',
    'Employee submitted formal overtime compensation complaint.',
    v_doc_emp_id,
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_evt_labor_2, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_case_labor_id, date '2026-03-15', 'internal_review',
    'HR and Legal collected attendance and payroll evidence.',
    v_doc_emp_id,
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_evt_labor_3, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_case_labor_id, date '2026-03-22', 'mediation_scheduled',
    'Initial mediation meeting scheduled with employee representative.',
    v_doc_nda_id,
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_evt_proc_1, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_case_proc_id, date '2026-03-12', 'vendor_notice',
    'Vendor issued notice disputing delay penalty calculation.',
    v_doc_po_id,
    v_actor_user_id, v_actor_user_id
  ),
  (
    v_evt_proc_2, v_org_id, v_company_id, v_branch_id, v_env, v_is_demo,
    v_case_proc_id, date '2026-03-19', 'legal_assessment',
    'Legal team completed initial contract clause assessment.',
    v_doc_po_id,
    v_actor_user_id, v_actor_user_id
  )
  on conflict (id) do update
  set event_date = excluded.event_date,
      event_type = excluded.event_type,
      description = excluded.description,
      source_document_id = excluded.source_document_id,
      updated_by = excluded.updated_by,
      updated_at = now();
end $$;

commit;


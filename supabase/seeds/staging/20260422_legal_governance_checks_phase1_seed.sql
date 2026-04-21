-- STAGING ONLY: legal governance checks Phase 1 read seed
-- Scope:
-- - production company for staging.tester2 canonical smoke
-- - sandbox company for selected-context isolation verification
-- Safe to run repeatedly (fixed ids + ON CONFLICT).

begin;

do $$
declare
  v_prod_org uuid := '10000000-0000-0000-0000-000000000001';
  v_prod_company uuid := '20000000-0000-0000-0000-000000000001';
  v_sandbox_org uuid := '10000000-0000-0000-0000-0000000000aa';
  v_sandbox_company uuid := '20000000-0000-0000-0000-0000000000aa';
begin
  if not exists (
    select 1
    from public.companies c
    where c.id = v_prod_company
      and c.org_id = v_prod_org
      and c.environment_type = 'production'
  ) then
    raise exception 'legal governance staging seed failed: production scope company not found';
  end if;

  if not exists (
    select 1
    from public.companies c
    where c.id = v_sandbox_company
      and c.org_id = v_sandbox_org
      and c.environment_type = 'sandbox'
  ) then
    raise exception 'legal governance staging seed failed: sandbox scope company not found';
  end if;

  insert into public.legal_governance_checks (
    id,
    org_id,
    company_id,
    branch_id,
    environment_type,
    is_demo,
    domain,
    check_type,
    target_object_type,
    target_object_id,
    jurisdiction_code,
    rule_strength,
    title,
    statutory_minimum_json,
    company_current_value_json,
    ai_suggested_value_json,
    deviation_type,
    severity,
    company_decision_status,
    impact_domain,
    reason_summary,
    source_ref_json,
    created_by_source,
    created_at,
    updated_at
  ) values
  (
    'c1000000-0000-0000-0000-000000000001',
    v_prod_org,
    v_prod_company,
    null,
    'production',
    false,
    'leave',
    'leave_policy',
    'company_leave_policy',
    'natural-disaster-leave-policy',
    'TW',
    'mandatory_minimum',
    '天然災害假給薪政策低於建議值',
    '{"summary":"不得直接視為曠職"}'::jsonb,
    '{"summary":"公司目前設定為 unpaid"}'::jsonb,
    '{"summary":"建議保留 unpaid，但不得扣全勤，並需明確標註為天災假"}'::jsonb,
    'below_recommended',
    'medium',
    'pending_review',
    'leave',
    '目前公司規則可能把天災假與一般缺勤混同，存在治理風險',
    '{"label":"天然災害出勤管理及工資給付要點","effective_from":"2025-09-19"}'::jsonb,
    'ai_scan',
    '2026-04-21T10:00:00Z',
    '2026-04-21T10:00:00Z'
  ),
  (
    'c1000000-0000-0000-0000-000000000002',
    v_prod_org,
    v_prod_company,
    null,
    'production',
    false,
    'payroll',
    'payroll_policy',
    'company_payroll_policy',
    'salary-advance-cutoff',
    'TW',
    'recommended_best_practice',
    '薪資預支結算規則未明確揭露',
    '{"summary":"工資項目與扣款規則應清楚揭露"}'::jsonb,
    '{"summary":"公司目前保留人工說明，未於制度中列明"}'::jsonb,
    '{"summary":"建議補上薪資預支、追補扣回與員工確認流程"}'::jsonb,
    'below_recommended',
    'high',
    'kept_current',
    'payroll',
    '公司雖保留現況，但薪資溝通不足可能造成工資爭議與申訴風險',
    '{"label":"工資各項目計算方式明示參考","effective_from":"2024-01-01"}'::jsonb,
    'scheduled_job',
    '2026-04-21T10:05:00Z',
    '2026-04-21T10:05:00Z'
  ),
  (
    'c1000000-0000-0000-0000-000000000003',
    v_prod_org,
    v_prod_company,
    null,
    'production',
    false,
    'contract',
    'contract_clause',
    'employment_contract_template',
    'employment-contract-template-v1',
    'TW',
    'company_discretion',
    '勞動契約遠距工作附錄建議補充資料保護條款',
    '{"summary":"法定最低未強制要求特定遠距附錄文字"}'::jsonb,
    '{"summary":"公司現況已採用基本保密條款"}'::jsonb,
    '{"summary":"AI 建議加入裝置安全、檔案保存與離職刪除責任條款"}'::jsonb,
    'below_recommended',
    'low',
    'adopted',
    'contract',
    '此項屬公司可裁量的契約治理強化，已決定採納建議文字',
    '{"label":"勞動契約書應約定及不得約定事項","effective_from":"2019-11-27"}'::jsonb,
    'manual_trigger',
    '2026-04-21T10:10:00Z',
    '2026-04-21T10:10:00Z'
  ),
  (
    'c1000000-0000-0000-0000-000000000004',
    v_sandbox_org,
    v_sandbox_company,
    null,
    'sandbox',
    false,
    'insurance',
    'insurance_recommendation',
    'company_insurance_policy',
    'field-service-rider',
    'TW',
    'recommended_best_practice',
    '外勤人員補充保險保障維持現況但已接受風險',
    '{"summary":"法定最低以勞保與職災保險為基礎"}'::jsonb,
    '{"summary":"sandbox 公司目前僅提供法定保險"}'::jsonb,
    '{"summary":"建議補充外勤意外附加保障，以降低高風險作業暴露"}'::jsonb,
    'below_recommended',
    'critical',
    'acknowledged_risk',
    'insurance',
    'sandbox 公司已知悉高風險外勤保障缺口，但暫不採納額外保單',
    '{"label":"職業災害保險及保護法參考","effective_from":"2022-05-01"}'::jsonb,
    'ai_scan',
    '2026-04-21T10:15:00Z',
    '2026-04-21T10:15:00Z'
  ),
  (
    'c1000000-0000-0000-0000-000000000005',
    v_sandbox_org,
    v_sandbox_company,
    null,
    'sandbox',
    false,
    'leave',
    'leave_policy',
    'company_leave_policy',
    'natural-disaster-leave-policy',
    'TW',
    'mandatory_minimum',
    'sandbox 天然災害假給薪政策低於建議值',
    '{"summary":"不得直接視為曠職"}'::jsonb,
    '{"summary":"sandbox 公司目前設定為 unpaid"}'::jsonb,
    '{"summary":"建議保留 unpaid，但不得扣全勤，並需明確標註為天災假"}'::jsonb,
    'below_recommended',
    'medium',
    'pending_review',
    'leave',
    'sandbox 公司規則可能把天災假與一般缺勤混同，存在治理風險',
    '{"label":"天然災害出勤管理及工資給付要點","effective_from":"2025-09-19"}'::jsonb,
    'ai_scan',
    '2026-04-21T10:20:00Z',
    '2026-04-21T10:20:00Z'
  ),
  (
    'c1000000-0000-0000-0000-000000000006',
    v_sandbox_org,
    v_sandbox_company,
    null,
    'sandbox',
    false,
    'payroll',
    'payroll_policy',
    'company_payroll_policy',
    'salary-advance-cutoff',
    'TW',
    'recommended_best_practice',
    'sandbox 薪資預支結算規則未明確揭露',
    '{"summary":"工資項目與扣款規則應清楚揭露"}'::jsonb,
    '{"summary":"sandbox 公司目前保留人工說明，未於制度中列明"}'::jsonb,
    '{"summary":"建議補上薪資預支、追補扣回與員工確認流程"}'::jsonb,
    'below_recommended',
    'high',
    'kept_current',
    'payroll',
    'sandbox 公司雖保留現況，但薪資溝通不足可能造成工資爭議與申訴風險',
    '{"label":"工資各項目計算方式明示參考","effective_from":"2024-01-01"}'::jsonb,
    'scheduled_job',
    '2026-04-21T10:25:00Z',
    '2026-04-21T10:25:00Z'
  ),
  (
    'c1000000-0000-0000-0000-000000000007',
    v_sandbox_org,
    v_sandbox_company,
    null,
    'sandbox',
    false,
    'contract',
    'contract_clause',
    'employment_contract_template',
    'employment-contract-template-v1',
    'TW',
    'company_discretion',
    'sandbox 勞動契約遠距工作附錄建議補充資料保護條款',
    '{"summary":"法定最低未強制要求特定遠距附錄文字"}'::jsonb,
    '{"summary":"sandbox 公司現況已採用基本保密條款"}'::jsonb,
    '{"summary":"AI 建議加入裝置安全、檔案保存與離職刪除責任條款"}'::jsonb,
    'below_recommended',
    'low',
    'adopted',
    'contract',
    'sandbox 此項屬公司可裁量的契約治理強化，已決定採納建議文字',
    '{"label":"勞動契約書應約定及不得約定事項","effective_from":"2019-11-27"}'::jsonb,
    'manual_trigger',
    '2026-04-21T10:30:00Z',
    '2026-04-21T10:30:00Z'
  )
  on conflict (id) do update
  set org_id = excluded.org_id,
      company_id = excluded.company_id,
      branch_id = excluded.branch_id,
      environment_type = excluded.environment_type,
      is_demo = excluded.is_demo,
      domain = excluded.domain,
      check_type = excluded.check_type,
      target_object_type = excluded.target_object_type,
      target_object_id = excluded.target_object_id,
      jurisdiction_code = excluded.jurisdiction_code,
      rule_strength = excluded.rule_strength,
      title = excluded.title,
      statutory_minimum_json = excluded.statutory_minimum_json,
      company_current_value_json = excluded.company_current_value_json,
      ai_suggested_value_json = excluded.ai_suggested_value_json,
      deviation_type = excluded.deviation_type,
      severity = excluded.severity,
      company_decision_status = excluded.company_decision_status,
      impact_domain = excluded.impact_domain,
      reason_summary = excluded.reason_summary,
      source_ref_json = excluded.source_ref_json,
      created_by_source = excluded.created_by_source,
      created_at = excluded.created_at,
      updated_at = excluded.updated_at;
end $$;

commit;

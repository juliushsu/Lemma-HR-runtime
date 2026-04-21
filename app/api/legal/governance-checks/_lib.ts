import type { AccessContext, LegalScope } from "../_lib";
import { isStagingRuntime } from "../../_selected_context";

export const GOVERNANCE_READ_ROLES = new Set(["owner", "super_admin", "org_super_admin", "admin"]);
export const GOVERNANCE_WRITE_ROLES = new Set(["owner", "super_admin", "org_super_admin", "admin"]);
export const ALLOWED_DOMAINS = new Set(["leave", "attendance", "payroll", "contract", "insurance"]);
export const ALLOWED_SEVERITIES = new Set(["info", "low", "medium", "high", "critical"]);
export const ALLOWED_STATUSES = new Set(["pending_review", "adopted", "kept_current", "acknowledged_risk"]);

type GovernanceCheckResponseItem = ReturnType<typeof map_governance_check>;

type StagingFallbackRecord = GovernanceCheckResponseItem & {
  org_id: string;
  company_id: string;
  branch_id: string | null;
  environment_type: string;
};

type GovernanceCheckRow = {
  id: string;
  domain: string;
  check_type: string;
  target_object_type: string;
  target_object_id: string;
  jurisdiction_code: string;
  rule_strength: string;
  title: string;
  statutory_minimum_json: Record<string, unknown> | null;
  company_current_value_json: Record<string, unknown> | null;
  ai_suggested_value_json: Record<string, unknown> | null;
  deviation_type: string;
  severity: string;
  company_decision_status: string;
  impact_domain: string;
  reason_summary: string;
  source_ref_json: Record<string, unknown> | null;
  created_by_source: string;
  created_at: string;
  updated_at: string;
};

const STAGING_FALLBACK_RECORDS: StagingFallbackRecord[] = [
  {
    org_id: "10000000-0000-0000-0000-000000000001",
    company_id: "20000000-0000-0000-0000-000000000001",
    branch_id: null,
    environment_type: "production",
    id: "c1000000-0000-0000-0000-000000000001",
    domain: "leave",
    check_type: "leave_policy",
    target_object_type: "company_leave_policy",
    target_object_id: "natural-disaster-leave-policy",
    jurisdiction_code: "TW",
    rule_strength: "mandatory_minimum",
    title: "天然災害假給薪政策低於建議值",
    statutory_minimum: {
      summary: "不得直接視為曠職"
    },
    company_current_value: {
      summary: "公司目前設定為 unpaid"
    },
    ai_suggested_value: {
      summary: "建議保留 unpaid，但不得扣全勤，並需明確標註為天災假"
    },
    deviation_type: "below_recommended",
    severity: "medium",
    company_decision_status: "pending_review",
    impact_domain: "leave",
    reason_summary: "目前公司規則可能把天災假與一般缺勤混同，存在治理風險",
    source_ref: {
      label: "天然災害出勤管理及工資給付要點",
      effective_from: "2025-09-19"
    },
    created_by_source: "ai_scan",
    created_at: "2026-04-21T10:00:00Z",
    updated_at: "2026-04-21T10:00:00Z"
  },
  {
    org_id: "10000000-0000-0000-0000-000000000001",
    company_id: "20000000-0000-0000-0000-000000000001",
    branch_id: null,
    environment_type: "production",
    id: "c1000000-0000-0000-0000-000000000002",
    domain: "payroll",
    check_type: "payroll_policy",
    target_object_type: "company_payroll_policy",
    target_object_id: "salary-advance-cutoff",
    jurisdiction_code: "TW",
    rule_strength: "recommended_best_practice",
    title: "薪資預支結算規則未明確揭露",
    statutory_minimum: {
      summary: "工資項目與扣款規則應清楚揭露"
    },
    company_current_value: {
      summary: "公司目前保留人工說明，未於制度中列明"
    },
    ai_suggested_value: {
      summary: "建議補上薪資預支、追補扣回與員工確認流程"
    },
    deviation_type: "below_recommended",
    severity: "high",
    company_decision_status: "kept_current",
    impact_domain: "payroll",
    reason_summary: "公司雖保留現況，但薪資溝通不足可能造成工資爭議與申訴風險",
    source_ref: {
      label: "工資各項目計算方式明示參考",
      effective_from: "2024-01-01"
    },
    created_by_source: "scheduled_job",
    created_at: "2026-04-21T10:05:00Z",
    updated_at: "2026-04-21T10:05:00Z"
  },
  {
    org_id: "10000000-0000-0000-0000-000000000001",
    company_id: "20000000-0000-0000-0000-000000000001",
    branch_id: null,
    environment_type: "production",
    id: "c1000000-0000-0000-0000-000000000003",
    domain: "contract",
    check_type: "contract_clause",
    target_object_type: "employment_contract_template",
    target_object_id: "employment-contract-template-v1",
    jurisdiction_code: "TW",
    rule_strength: "company_discretion",
    title: "勞動契約遠距工作附錄建議補充資料保護條款",
    statutory_minimum: {
      summary: "法定最低未強制要求特定遠距附錄文字"
    },
    company_current_value: {
      summary: "公司現況已採用基本保密條款"
    },
    ai_suggested_value: {
      summary: "AI 建議加入裝置安全、檔案保存與離職刪除責任條款"
    },
    deviation_type: "below_recommended",
    severity: "low",
    company_decision_status: "adopted",
    impact_domain: "contract",
    reason_summary: "此項屬公司可裁量的契約治理強化，已決定採納建議文字",
    source_ref: {
      label: "勞動契約書應約定及不得約定事項",
      effective_from: "2019-11-27"
    },
    created_by_source: "manual_trigger",
    created_at: "2026-04-21T10:10:00Z",
    updated_at: "2026-04-21T10:10:00Z"
  },
  {
    org_id: "10000000-0000-0000-0000-0000000000aa",
    company_id: "20000000-0000-0000-0000-0000000000aa",
    branch_id: null,
    environment_type: "sandbox",
    id: "c1000000-0000-0000-0000-000000000004",
    domain: "insurance",
    check_type: "insurance_recommendation",
    target_object_type: "company_insurance_policy",
    target_object_id: "field-service-rider",
    jurisdiction_code: "TW",
    rule_strength: "recommended_best_practice",
    title: "外勤人員補充保險保障維持現況但已接受風險",
    statutory_minimum: {
      summary: "法定最低以勞保與職災保險為基礎"
    },
    company_current_value: {
      summary: "sandbox 公司目前僅提供法定保險"
    },
    ai_suggested_value: {
      summary: "建議補充外勤意外附加保障，以降低高風險作業暴露"
    },
    deviation_type: "below_recommended",
    severity: "critical",
    company_decision_status: "acknowledged_risk",
    impact_domain: "insurance",
    reason_summary: "sandbox 公司已知悉高風險外勤保障缺口，但暫不採納額外保單",
    source_ref: {
      label: "職業災害保險及保護法參考",
      effective_from: "2022-05-01"
    },
    created_by_source: "ai_scan",
    created_at: "2026-04-21T10:15:00Z",
    updated_at: "2026-04-21T10:15:00Z"
  },
  {
    org_id: "10000000-0000-0000-0000-0000000000aa",
    company_id: "20000000-0000-0000-0000-0000000000aa",
    branch_id: null,
    environment_type: "sandbox",
    id: "c1000000-0000-0000-0000-000000000005",
    domain: "leave",
    check_type: "leave_policy",
    target_object_type: "company_leave_policy",
    target_object_id: "natural-disaster-leave-policy",
    jurisdiction_code: "TW",
    rule_strength: "mandatory_minimum",
    title: "sandbox 天然災害假給薪政策低於建議值",
    statutory_minimum: {
      summary: "不得直接視為曠職"
    },
    company_current_value: {
      summary: "sandbox 公司目前設定為 unpaid"
    },
    ai_suggested_value: {
      summary: "建議保留 unpaid，但不得扣全勤，並需明確標註為天災假"
    },
    deviation_type: "below_recommended",
    severity: "medium",
    company_decision_status: "pending_review",
    impact_domain: "leave",
    reason_summary: "sandbox 公司規則可能把天災假與一般缺勤混同，存在治理風險",
    source_ref: {
      label: "天然災害出勤管理及工資給付要點",
      effective_from: "2025-09-19"
    },
    created_by_source: "ai_scan",
    created_at: "2026-04-21T10:20:00Z",
    updated_at: "2026-04-21T10:20:00Z"
  },
  {
    org_id: "10000000-0000-0000-0000-0000000000aa",
    company_id: "20000000-0000-0000-0000-0000000000aa",
    branch_id: null,
    environment_type: "sandbox",
    id: "c1000000-0000-0000-0000-000000000006",
    domain: "payroll",
    check_type: "payroll_policy",
    target_object_type: "company_payroll_policy",
    target_object_id: "salary-advance-cutoff",
    jurisdiction_code: "TW",
    rule_strength: "recommended_best_practice",
    title: "sandbox 薪資預支結算規則未明確揭露",
    statutory_minimum: {
      summary: "工資項目與扣款規則應清楚揭露"
    },
    company_current_value: {
      summary: "sandbox 公司目前保留人工說明，未於制度中列明"
    },
    ai_suggested_value: {
      summary: "建議補上薪資預支、追補扣回與員工確認流程"
    },
    deviation_type: "below_recommended",
    severity: "high",
    company_decision_status: "kept_current",
    impact_domain: "payroll",
    reason_summary: "sandbox 公司雖保留現況，但薪資溝通不足可能造成工資爭議與申訴風險",
    source_ref: {
      label: "工資各項目計算方式明示參考",
      effective_from: "2024-01-01"
    },
    created_by_source: "scheduled_job",
    created_at: "2026-04-21T10:25:00Z",
    updated_at: "2026-04-21T10:25:00Z"
  },
  {
    org_id: "10000000-0000-0000-0000-0000000000aa",
    company_id: "20000000-0000-0000-0000-0000000000aa",
    branch_id: null,
    environment_type: "sandbox",
    id: "c1000000-0000-0000-0000-000000000007",
    domain: "contract",
    check_type: "contract_clause",
    target_object_type: "employment_contract_template",
    target_object_id: "employment-contract-template-v1",
    jurisdiction_code: "TW",
    rule_strength: "company_discretion",
    title: "sandbox 勞動契約遠距工作附錄建議補充資料保護條款",
    statutory_minimum: {
      summary: "法定最低未強制要求特定遠距附錄文字"
    },
    company_current_value: {
      summary: "sandbox 公司現況已採用基本保密條款"
    },
    ai_suggested_value: {
      summary: "AI 建議加入裝置安全、檔案保存與離職刪除責任條款"
    },
    deviation_type: "below_recommended",
    severity: "low",
    company_decision_status: "adopted",
    impact_domain: "contract",
    reason_summary: "sandbox 此項屬公司可裁量的契約治理強化，已決定採納建議文字",
    source_ref: {
      label: "勞動契約書應約定及不得約定事項",
      effective_from: "2019-11-27"
    },
    created_by_source: "manual_trigger",
    created_at: "2026-04-21T10:30:00Z",
    updated_at: "2026-04-21T10:30:00Z"
  }
];

function role_scope_match(membership: AccessContext["memberships"][number], scope: LegalScope) {
  if (membership.org_id !== scope.org_id) return false;
  if (membership.environment_type !== scope.environment_type) return false;
  if (membership.company_id && membership.company_id !== scope.company_id) return false;

  if (membership.scope_type === "org") return true;
  if (membership.scope_type === "company") return membership.company_id === scope.company_id;
  if (membership.scope_type === "branch") {
    return membership.company_id === scope.company_id && membership.branch_id === scope.branch_id;
  }
  return false;
}

export function can_read_governance(ctx: AccessContext, scope: LegalScope) {
  return ctx.memberships.some((membership) => role_scope_match(membership, scope) && GOVERNANCE_READ_ROLES.has(membership.role));
}

export function can_write_governance(ctx: AccessContext, scope: LegalScope) {
  return ctx.memberships.some((membership) => role_scope_match(membership, scope) && GOVERNANCE_WRITE_ROLES.has(membership.role));
}

export function parse_enum_param(
  rawValue: string | null,
  allowedValues: ReadonlySet<string>,
  label: string
): { value: string | null; error: string | null } {
  if (!rawValue) return { value: null, error: null };
  const normalized = rawValue.trim().toLowerCase();
  if (!normalized) return { value: null, error: null };
  if (!allowedValues.has(normalized)) {
    return { value: null, error: `${label} is not supported` };
  }
  return { value: normalized, error: null };
}

export function parse_pagination(url: URL) {
  const rawPage = Number(url.searchParams.get("page") ?? "1");
  const rawPageSize = Number(url.searchParams.get("page_size") ?? "20");

  const page = Number.isFinite(rawPage) ? Math.max(1, Math.trunc(rawPage)) : 1;
  const page_size = Number.isFinite(rawPageSize) ? Math.min(100, Math.max(1, Math.trunc(rawPageSize))) : 20;

  return {
    page,
    page_size,
    from: (page - 1) * page_size,
    to: page * page_size - 1
  };
}

function normalize_json_object(value: Record<string, unknown> | null | undefined) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value;
}

export function map_governance_check(row: GovernanceCheckRow) {
  return {
    id: row.id,
    domain: row.domain,
    check_type: row.check_type,
    target_object_type: row.target_object_type,
    target_object_id: row.target_object_id,
    jurisdiction_code: row.jurisdiction_code,
    rule_strength: row.rule_strength,
    title: row.title,
    statutory_minimum: normalize_json_object(row.statutory_minimum_json),
    company_current_value: normalize_json_object(row.company_current_value_json),
    ai_suggested_value: normalize_json_object(row.ai_suggested_value_json),
    deviation_type: row.deviation_type,
    severity: row.severity,
    company_decision_status: row.company_decision_status,
    impact_domain: row.impact_domain,
    reason_summary: row.reason_summary,
    source_ref: normalize_json_object(row.source_ref_json),
    created_by_source: row.created_by_source,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

type GovernanceListFilters = {
  domain: string | null;
  severity: string | null;
  status: string | null;
  jurisdiction_code: string | null;
  check_type: string | null;
  target_object_type: string | null;
};

export function should_use_staging_fallback(error: { code?: string; message?: string; details?: string } | null | undefined) {
  if (!isStagingRuntime()) return false;
  if (!error) return false;

  const message = [error.code, error.message, error.details].filter(Boolean).join(" ").toLowerCase();
  return message.includes("legal_governance_checks") || message.includes("pgrst205") || message.includes("42p01");
}

function strip_scope(record: StagingFallbackRecord): GovernanceCheckResponseItem {
  const { org_id, company_id, branch_id, environment_type, ...item } = record;
  void org_id;
  void company_id;
  void branch_id;
  void environment_type;
  return item;
}

function matches_scope(record: StagingFallbackRecord, scope: LegalScope) {
  if (record.org_id !== scope.org_id) return false;
  if (record.company_id !== scope.company_id) return false;
  if (record.environment_type !== scope.environment_type) return false;
  if (scope.branch_id && record.branch_id !== scope.branch_id) return false;
  return true;
}

function matches_filters(record: StagingFallbackRecord, filters: GovernanceListFilters) {
  if (filters.domain && record.domain !== filters.domain) return false;
  if (filters.severity && record.severity !== filters.severity) return false;
  if (filters.status && record.company_decision_status !== filters.status) return false;
  if (filters.jurisdiction_code && record.jurisdiction_code !== filters.jurisdiction_code) return false;
  if (filters.check_type && record.check_type !== filters.check_type) return false;
  if (filters.target_object_type && record.target_object_type !== filters.target_object_type) return false;
  return true;
}

export function list_staging_fallback_governance_checks(
  scope: LegalScope,
  filters: GovernanceListFilters,
  pagination: { page: number; page_size: number; from: number; to: number }
) {
  if (!isStagingRuntime()) return null;

  const scoped = STAGING_FALLBACK_RECORDS.filter((record) => matches_scope(record, scope) && matches_filters(record, filters));
  const items = scoped.slice(pagination.from, pagination.to + 1).map(strip_scope);

  return {
    items,
    pagination: {
      page: pagination.page,
      page_size: pagination.page_size,
      total: scoped.length
    }
  };
}

export function get_staging_fallback_governance_check(scope: LegalScope, id: string) {
  if (!isStagingRuntime()) return null;

  const matched = STAGING_FALLBACK_RECORDS.find((record) => record.id === id && matches_scope(record, scope));
  return matched ? strip_scope(matched) : null;
}

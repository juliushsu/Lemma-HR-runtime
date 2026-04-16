import { apply_scope, fail, get_access_context, ok, resolve_scope, type AccessContext, type Scope } from "../hr/_lib";

const PORTAL_READ_ROLES = new Set(["owner", "super_admin", "org_super_admin", "admin", "manager", "operator", "viewer", "portal_user"]);
const DEPARTURE_STATUSES = new Set(["terminated", "resigned", "inactive", "offboarded"]);
const DOC_PENDING_SIGNOFF_STATUSES = new Set(["draft", "pending", "in_progress", "review"]);

export type AiRuleContext = {
  attendance_rate?: number | null;
  pending_legal_case_count?: number | null;
  pending_compliance_signal_count?: number | null;
  expiring_document_30d_count?: number | null;
};

export type AiRuleInputs = {
  data_completeness_score: number;
  missing_profile_count: number;
  new_hires_30d: number;
  departures_count: number;
  attendance_rate: number | null;
  pending_legal_case_count: number;
  pending_compliance_signal_count: number;
  expiring_document_30d_count: number;
};

export type AiInsight = {
  insight_id: string;
  severity: "info" | "warning" | "critical";
  title: string;
  message: string;
  source: "rule_based_v1";
  trigger_reason: string;
};

function role_scope_match(m: AccessContext["memberships"][number], scope: Scope) {
  if (m.org_id !== scope.org_id) return false;
  if (m.environment_type !== scope.environment_type) return false;
  if (m.company_id && m.company_id !== scope.company_id) return false;

  if (m.scope_type === "org") return true;
  if (m.scope_type === "company") return m.company_id === scope.company_id;
  if (m.scope_type === "branch") return m.company_id === scope.company_id && m.branch_id === scope.branch_id;
  if (m.scope_type === "self") return true;
  return false;
}

export async function ensure_portal_access(request: Request) {
  const ctx = await get_access_context(request);
  if (!ctx) {
    return {
      ctx: null as AccessContext | null,
      scope: null as Scope | null,
      denied: fail("portal.security.v1", "UNAUTHORIZED", "Unauthorized", 401)
    };
  }

  const scope = resolve_scope(ctx, request);
  if (!scope) {
    return {
      ctx,
      scope: null as Scope | null,
      denied: fail("portal.security.v1", "SCOPE_FORBIDDEN", "Scope not accessible", 403)
    };
  }

  const membership_allowed = ctx.memberships.some((m) => role_scope_match(m, scope) && PORTAL_READ_ROLES.has(m.role));
  if (membership_allowed) return { ctx, scope, denied: null as Response | null };

  const { data: is_portal_user } = await ctx.supabase.rpc("is_portal_user", { p_user_id: ctx.user_id });
  if (is_portal_user === true) return { ctx, scope, denied: null as Response | null };

  return {
    ctx,
    scope,
    denied: fail("portal.security.v1", "SCOPE_FORBIDDEN", "Portal access is not allowed", 403)
  };
}

export async function load_people_base(ctx: AccessContext, scope: Scope) {
  const [employeesRes, departmentsRes, positionsRes] = await Promise.all([
    apply_scope(
      ctx.supabase
        .from("employees")
        .select("id,employee_code,display_name,full_name_local,full_name_latin,employment_status,employment_type,hire_date,department_id,position_id,manager_employee_id,updated_at"),
      scope
    ),
    apply_scope(
      ctx.supabase.from("departments").select("id,department_name,is_active,updated_at"),
      scope
    ),
    apply_scope(
      ctx.supabase.from("positions").select("id,position_name,is_managerial"),
      scope
    )
  ]);

  if (employeesRes.error || departmentsRes.error || positionsRes.error) {
    return {
      error: fail("portal.data.v1", "INTERNAL_ERROR", "Failed to load portal data", 500),
      employees: [] as any[],
      departments: [] as any[],
      positions: [] as any[]
    };
  }

  return {
    error: null as Response | null,
    employees: employeesRes.data ?? [],
    departments: departmentsRes.data ?? [],
    positions: positionsRes.data ?? []
  };
}

export function compute_people_insights(employees: any[]) {
  const headcount_distribution: Record<string, number> = {};
  let new_hires_count = 0;
  let departures_count = 0;
  const now = Date.now();
  const in30days = 30 * 24 * 60 * 60 * 1000;

  let complete_count = 0;
  const missing_fields = {
    full_name_local: 0,
    department_id: 0,
    position_id: 0,
    hire_date: 0,
    employment_status: 0
  };

  for (const e of employees) {
    const status = String(e.employment_status ?? "unknown");
    headcount_distribution[status] = (headcount_distribution[status] ?? 0) + 1;

    if (e.hire_date) {
      const hireTs = new Date(e.hire_date).getTime();
      if (!Number.isNaN(hireTs) && now - hireTs <= in30days && hireTs <= now) new_hires_count += 1;
    }

    if (is_departed_status(status)) departures_count += 1;

    const has_local = !!e.full_name_local;
    const has_dept = !!e.department_id;
    const has_pos = !!e.position_id;
    const has_hire = !!e.hire_date;
    const has_status = !!e.employment_status;
    if (has_local && has_dept && has_pos && has_hire && has_status) complete_count += 1;
    if (!has_local) missing_fields.full_name_local += 1;
    if (!has_dept) missing_fields.department_id += 1;
    if (!has_pos) missing_fields.position_id += 1;
    if (!has_hire) missing_fields.hire_date += 1;
    if (!has_status) missing_fields.employment_status += 1;
  }

  const total = employees.length;
  const score = total === 0 ? 0 : Number((complete_count / total).toFixed(4));

  return {
    headcount_distribution,
    new_hires_count,
    departures_count,
    data_completeness: {
      score,
      complete_count,
      total_count: total,
      missing_fields
    }
  };
}

export function is_departed_status(status: string | null | undefined) {
  return DEPARTURE_STATUSES.has(String(status ?? "").toLowerCase());
}

export function compute_org_health(employees: any[], departments: any[], positions: any[]) {
  const positionById = new Map(positions.map((p) => [p.id, p]));
  const employeeById = new Map(employees.map((e) => [e.id, e]));
  const directReportsMap = new Map<string, number>();

  for (const e of employees) {
    if (!e.manager_employee_id) continue;
    directReportsMap.set(e.manager_employee_id, (directReportsMap.get(e.manager_employee_id) ?? 0) + 1);
  }

  let manager_count = 0;
  let root_count = 0;
  let orphan_count = 0;

  for (const e of employees) {
    const directReports = directReportsMap.get(e.id) ?? 0;
    const isManagerByReports = directReports > 0;
    const isManagerByPosition = !!positionById.get(e.position_id)?.is_managerial;
    if (isManagerByReports || isManagerByPosition) manager_count += 1;

    if (!e.manager_employee_id) root_count += 1;
    if (e.manager_employee_id && !employeeById.has(e.manager_employee_id)) orphan_count += 1;
  }

  const department_stats = departments.map((d) => {
    const members = employees.filter((e) => e.department_id === d.id);
    const deptManagers = members.filter((e) => {
      const directReports = directReportsMap.get(e.id) ?? 0;
      return directReports > 0 || !!positionById.get(e.position_id)?.is_managerial;
    });
    return {
      department_id: d.id,
      department_name: d.department_name,
      member_count: members.length,
      manager_count: deptManagers.length,
      active: d.is_active ?? true
    };
  });

  const employee_count = employees.length;
  const manager_ratio = employee_count === 0 ? 0 : Number((manager_count / employee_count).toFixed(4));

  return {
    department_stats,
    manager_ratio,
    org_structure_summary: {
      employee_count,
      manager_count,
      staff_count: Math.max(employee_count - manager_count, 0),
      root_count,
      orphan_count
    }
  };
}

export function compute_ai_insights(
  peopleInsights: ReturnType<typeof compute_people_insights>,
  context: AiRuleContext = {}
) {
  return compute_ai_insights_from_rule_inputs(compute_ai_rule_inputs(peopleInsights, context));
}

function clamp_ratio(value: unknown) {
  const n = Number(value ?? 0);
  if (Number.isNaN(n) || !Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

export function compute_ai_rule_inputs(
  peopleInsights: ReturnType<typeof compute_people_insights>,
  context: AiRuleContext = {}
): AiRuleInputs {
  const total_count = Number(peopleInsights.data_completeness?.total_count ?? 0);
  const complete_count = Number(peopleInsights.data_completeness?.complete_count ?? 0);
  const missing_profile_count = Math.max(total_count - complete_count, 0);

  return {
    data_completeness_score: clamp_ratio(peopleInsights.data_completeness?.score ?? 0),
    missing_profile_count,
    new_hires_30d: Number(peopleInsights.new_hires_count ?? 0),
    departures_count: Number(peopleInsights.departures_count ?? 0),
    attendance_rate:
      context.attendance_rate === null || context.attendance_rate === undefined ? null : clamp_ratio(context.attendance_rate),
    pending_legal_case_count: Math.max(Number(context.pending_legal_case_count ?? 0), 0),
    pending_compliance_signal_count: Math.max(Number(context.pending_compliance_signal_count ?? 0), 0),
    expiring_document_30d_count: Math.max(Number(context.expiring_document_30d_count ?? 0), 0)
  };
}

function compute_ai_insights_from_rule_inputs(rule_inputs: AiRuleInputs): AiInsight[] {
  const insights: AiInsight[] = [];

  if (rule_inputs.data_completeness_score < 0.8) {
    insights.push({
      insight_id: "data_completeness_low",
      severity: "warning",
      title: "Data Completeness Is Low",
      message: `Employee data completeness is ${(rule_inputs.data_completeness_score * 100).toFixed(1)}%.`,
      source: "rule_based_v1",
      trigger_reason: `data_completeness_score=${rule_inputs.data_completeness_score}`
    });
  }

  if (rule_inputs.pending_compliance_signal_count > 0) {
    const severity = rule_inputs.pending_compliance_signal_count >= 2 ? "critical" : "warning";
    insights.push({
      insight_id: "compliance_signal_watch",
      severity,
      title: "Pending Compliance Signals",
      message: `${rule_inputs.pending_compliance_signal_count} unresolved compliance signal(s) need review.`,
      source: "rule_based_v1",
      trigger_reason: `pending_compliance_signal_count=${rule_inputs.pending_compliance_signal_count}`
    });
  }

  if (rule_inputs.attendance_rate !== null && rule_inputs.attendance_rate < 0.9) {
    insights.push({
      insight_id: "attendance_health_watch",
      severity: "warning",
      title: "Attendance Health Below Target",
      message: `Current month normal attendance rate is ${(rule_inputs.attendance_rate * 100).toFixed(1)}%.`,
      source: "rule_based_v1",
      trigger_reason: `attendance_rate=${rule_inputs.attendance_rate}`
    });
  }

  if (rule_inputs.pending_legal_case_count > 0) {
    insights.push({
      insight_id: "pending_legal_case_watch",
      severity: rule_inputs.pending_legal_case_count >= 3 ? "warning" : "info",
      title: "Pending Legal Case Follow-up",
      message: `${rule_inputs.pending_legal_case_count} legal case(s) are still open or under review.`,
      source: "rule_based_v1",
      trigger_reason: `pending_legal_case_count=${rule_inputs.pending_legal_case_count}`
    });
  }

  if (rule_inputs.new_hires_30d > 0) {
    insights.push({
      insight_id: "new_hire_watch",
      severity: "info",
      title: "New Hire Cohort",
      message: `${rule_inputs.new_hires_30d} new hire(s) in the last 30 days.`,
      source: "rule_based_v1",
      trigger_reason: `new_hires_30d=${rule_inputs.new_hires_30d}`
    });
  }

  if (insights.length === 0) {
    insights.push({
      insight_id: "baseline_stable",
      severity: "info",
      title: "Org Data Stable",
      message: "No critical people-data anomalies detected by current rules.",
      source: "rule_based_v1",
      trigger_reason: "rules_stable"
    });
  }

  return insights;
}

export function summarize_ai_insights(insights: AiInsight[]) {
  const total_count = insights.length;
  const critical_count = insights.filter((x) => x.severity === "critical").length;
  const warning_count = insights.filter((x) => x.severity === "warning").length;
  const info_count = insights.filter((x) => x.severity === "info").length;
  const top_severity =
    critical_count > 0 ? "critical" : warning_count > 0 ? "warning" : "info";

  return {
    total_count,
    critical_count,
    warning_count,
    info_count,
    top_severity
  };
}

export function build_recent_changes(employees: any[], departments: any[]) {
  const changes = [
    ...employees.map((e) => ({
      change_type: "employee_updated",
      ref_id: e.employee_code ?? e.id,
      title: e.full_name_local ?? e.full_name_latin ?? e.display_name ?? e.employee_code ?? "Employee",
      changed_at: e.updated_at ?? null
    })),
    ...departments.map((d) => ({
      change_type: "department_updated",
      ref_id: d.id,
      title: d.department_name ?? "Department",
      changed_at: d.updated_at ?? null
    }))
  ];

  return changes
    .sort((a, b) => String(b.changed_at ?? "").localeCompare(String(a.changed_at ?? "")))
    .slice(0, 8);
}

export function build_alerts(peopleInsights: ReturnType<typeof compute_people_insights>) {
  const alerts: Array<{ alert_code: string; severity: "info" | "warning"; message: string }> = [];

  if (peopleInsights.data_completeness.score < 0.8) {
    alerts.push({
      alert_code: "LOW_COMPLETENESS",
      severity: "warning",
      message: "Some employee profiles are incomplete."
    });
  }

  if (peopleInsights.departures_count > 0) {
    alerts.push({
      alert_code: "HAS_DEPARTURES",
      severity: "info",
      message: `${peopleInsights.departures_count} departure record(s) detected.`
    });
  }

  return alerts;
}

function current_month_date_range_utc() {
  const now = new Date();
  const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const to = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0));
  const date_from = from.toISOString().slice(0, 10);
  const date_to = to.toISOString().slice(0, 10);
  const month_key = `${from.getUTCFullYear()}-${String(from.getUTCMonth() + 1).padStart(2, "0")}`;
  return { date_from, date_to, month_key };
}

export async function load_monthly_attendance_health(ctx: AccessContext, scope: Scope) {
  const { date_from, date_to, month_key } = current_month_date_range_utc();
  const fallback = {
    month_key,
    date_from,
    date_to,
    attendance_rate: 0,
    total_logs: 0,
    valid_logs: 0,
    normal_logs: 0
  };

  const { data, error } = await apply_scope(
    ctx.supabase
      .from("attendance_logs")
      .select("id,status_code,is_valid,attendance_date")
      .gte("attendance_date", date_from)
      .lte("attendance_date", date_to),
    scope
  );

  if (error) return fallback;

  const logs = data ?? [];
  const valid_logs = logs.filter((r: any) => r?.is_valid !== false);
  const normal_logs = valid_logs.filter((r: any) => String(r?.status_code ?? "") === "normal");
  const attendance_rate = valid_logs.length === 0 ? 0 : Number((normal_logs.length / valid_logs.length).toFixed(4));

  return {
    month_key,
    date_from,
    date_to,
    attendance_rate,
    total_logs: logs.length,
    valid_logs: valid_logs.length,
    normal_logs: normal_logs.length
  };
}

export async function load_pending_legal_case_summary(ctx: AccessContext, scope: Scope) {
  const fallback = {
    pending_case_count: 0,
    total_case_count: 0
  };
  const pendingStatuses = new Set(["open", "pending", "in_progress", "review", "pending_review", "investigating"]);
  const closedStatuses = new Set(["closed", "resolved", "done", "cancelled", "archived"]);

  const { data, error } = await apply_scope(ctx.supabase.from("legal_cases").select("id,status"), scope);
  if (error) return fallback;

  const rows = data ?? [];
  let pending_case_count = 0;
  for (const row of rows) {
    const status = String(row?.status ?? "").trim().toLowerCase();
    if (!status || pendingStatuses.has(status) || !closedStatuses.has(status)) pending_case_count += 1;
  }

  return {
    pending_case_count,
    total_case_count: rows.length
  };
}

function to_iso_date(value: Date) {
  return value.toISOString().slice(0, 10);
}

function normalize_signal_severity(value: unknown): "info" | "warning" | "critical" {
  const v = String(value ?? "").toLowerCase();
  if (v === "high" || v === "critical") return "critical";
  if (v === "medium" || v === "warning") return "warning";
  return "info";
}

export async function load_compliance_story_summary(ctx: AccessContext, scope: Scope) {
  const today = new Date();
  const date_today = to_iso_date(today);
  const in30 = new Date(today);
  in30.setUTCDate(in30.getUTCDate() + 30);
  const date_30 = to_iso_date(in30);

  const fallback = {
    pending_compliance_signal_count: 0,
    critical_compliance_signal_count: 0,
    expiring_document_30d_count: 0,
    pending_document_signoff_count: 0
  };

  const [documentsRes, warningsRes] = await Promise.all([
    apply_scope(ctx.supabase.from("legal_documents").select("id,expiry_date,signing_status"), scope),
    apply_scope(
      ctx.supabase
        .from("leave_compliance_warnings")
        .select("id,severity,is_resolved")
        .eq("is_resolved", false),
      scope
    )
  ]);

  if (documentsRes.error && warningsRes.error) return fallback;

  const documents = documentsRes.error ? [] : (documentsRes.data ?? []);
  const warnings = warningsRes.error ? [] : (warningsRes.data ?? []);
  const expiring_document_30d_count = documents.filter((d: any) => {
    if (!d.expiry_date) return false;
    const date = String(d.expiry_date);
    return date >= date_today && date <= date_30;
  }).length;
  const pending_document_signoff_count = documents.filter((d: any) =>
    DOC_PENDING_SIGNOFF_STATUSES.has(String(d.signing_status ?? "").toLowerCase())
  ).length;
  const pending_compliance_signal_count = warnings.length;
  const critical_compliance_signal_count = warnings.filter(
    (w: any) => normalize_signal_severity(w.severity) === "critical"
  ).length;

  return {
    pending_compliance_signal_count,
    critical_compliance_signal_count,
    expiring_document_30d_count,
    pending_document_signoff_count
  };
}

export { ok, fail };

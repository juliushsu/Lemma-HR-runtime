import {
  build_alerts,
  build_recent_changes,
  compute_ai_rule_inputs,
  compute_ai_insights,
  compute_org_health,
  compute_people_insights,
  ensure_portal_access,
  is_departed_status,
  load_compliance_story_summary,
  load_monthly_attendance_health,
  load_pending_legal_case_summary,
  load_people_base,
  ok,
  summarize_ai_insights
} from "../_lib";

export async function GET(request: Request) {
  const schema_version = "portal.overview.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const loaded = await load_people_base(access.ctx, access.scope);
  if (loaded.error) return loaded.error;

  const peopleInsights = compute_people_insights(loaded.employees);
  const orgHealth = compute_org_health(loaded.employees, loaded.departments, loaded.positions);
  const recent_changes = build_recent_changes(loaded.employees, loaded.departments);
  const attendance = await load_monthly_attendance_health(access.ctx, access.scope);
  const legal = await load_pending_legal_case_summary(access.ctx, access.scope);
  const compliance = await load_compliance_story_summary(access.ctx, access.scope);
  const alerts = build_alerts(peopleInsights);
  if (compliance.pending_compliance_signal_count > 0) {
    alerts.push({
      alert_code: "HAS_COMPLIANCE_SIGNALS",
      severity: compliance.critical_compliance_signal_count > 0 ? "warning" : "info",
      message: `${compliance.pending_compliance_signal_count} unresolved compliance signal(s) detected.`
    });
  }
  if (compliance.expiring_document_30d_count > 0) {
    alerts.push({
      alert_code: "HAS_EXPIRING_DOCUMENTS",
      severity: "warning",
      message: `${compliance.expiring_document_30d_count} document(s) expiring within 30 days.`
    });
  }

  const ai_rule_context = {
    attendance_rate: attendance.attendance_rate,
    pending_legal_case_count: legal.pending_case_count,
    pending_compliance_signal_count: compliance.pending_compliance_signal_count,
    expiring_document_30d_count: compliance.expiring_document_30d_count
  };
  const ai_rule_inputs = compute_ai_rule_inputs(peopleInsights, ai_rule_context);
  const ai_insights = compute_ai_insights(peopleInsights, ai_rule_context);
  const ai_summary = summarize_ai_insights(ai_insights);
  const active_employee_count = loaded.employees.filter((e) => !is_departed_status(e.employment_status)).length;
  const ai_insights_unread_count = ai_insights.length;
  const recent_activity = recent_changes.map((item) => ({
    id: `${item.change_type}:${item.ref_id}`,
    activity_type: item.change_type,
    title: item.title,
    event_at: item.changed_at,
    source: "portal.recent_changes"
  }));

  return ok(schema_version, {
    org_id: access.scope.org_id,
    company_id: access.scope.company_id,
    employee_count: loaded.employees.length,
    department_count: loaded.departments.length,
    recent_changes,
    recent_activity,
    alerts,
    ai_insights,
    ai_rule_inputs,
    ai_summary,
    monthly_attendance_health: attendance,
    legal_case_summary: legal,
    kpi_summary: {
      active_employee_count,
      monthly_attendance_rate: attendance.attendance_rate,
      pending_legal_case_count: legal.pending_case_count,
      pending_compliance_signal_count: compliance.pending_compliance_signal_count,
      ai_insights_unread_count
    },
    ui_cards: {
      active_employees: {
        key: "active_employees",
        label: "在職員工",
        value: active_employee_count
      },
      monthly_attendance_rate: {
        key: "monthly_attendance_rate",
        label: "本月出勤率",
        value: attendance.attendance_rate
      },
      pending_legal_cases: {
        key: "pending_legal_cases",
        label: "待處理法務案件",
        value: legal.pending_case_count
      },
      ai_insights_unread: {
        key: "ai_insights_unread",
        label: "AI 洞察待查看",
        value: ai_insights_unread_count
      }
    },
    summary: {
      manager_ratio: orgHealth.manager_ratio,
      data_completeness_score: peopleInsights.data_completeness.score,
      narrative_status: ai_summary.top_severity
    },
    narrative_summary: {
      active_employee_count,
      departures_count: peopleInsights.departures_count,
      new_hires_count: peopleInsights.new_hires_count,
      data_completeness_score: peopleInsights.data_completeness.score,
      attendance_rate: attendance.attendance_rate,
      pending_legal_case_count: legal.pending_case_count,
      pending_compliance_signal_count: compliance.pending_compliance_signal_count,
      expiring_document_30d_count: compliance.expiring_document_30d_count
    },
    // camelCase aliases for frontend adapters.
    recentActivity: recent_activity,
    aiRuleInputs: ai_rule_inputs,
    aiSummary: ai_summary,
    monthlyAttendanceHealth: attendance,
    legalCaseSummary: legal,
    kpiSummary: {
      activeEmployeeCount: active_employee_count,
      monthlyAttendanceRate: attendance.attendance_rate,
      pendingLegalCaseCount: legal.pending_case_count,
      pendingComplianceSignalCount: compliance.pending_compliance_signal_count,
      aiInsightsUnreadCount: ai_insights_unread_count
    },
    uiCards: {
      activeEmployees: {
        key: "active_employees",
        label: "在職員工",
        value: active_employee_count
      },
      monthlyAttendanceRate: {
        key: "monthly_attendance_rate",
        label: "本月出勤率",
        value: attendance.attendance_rate
      },
      pendingLegalCases: {
        key: "pending_legal_cases",
        label: "待處理法務案件",
        value: legal.pending_case_count
      },
      aiInsightsUnread: {
        key: "ai_insights_unread",
        label: "AI 洞察待查看",
        value: ai_insights_unread_count
      }
    },
    narrativeSummary: {
      activeEmployeeCount: active_employee_count,
      departuresCount: peopleInsights.departures_count,
      newHiresCount: peopleInsights.new_hires_count,
      dataCompletenessScore: peopleInsights.data_completeness.score,
      attendanceRate: attendance.attendance_rate,
      pendingLegalCaseCount: legal.pending_case_count,
      pendingComplianceSignalCount: compliance.pending_compliance_signal_count,
      expiringDocument30dCount: compliance.expiring_document_30d_count
    }
  });
}

import {
  compute_ai_insights,
  compute_ai_rule_inputs,
  compute_people_insights,
  ensure_portal_access,
  load_compliance_story_summary,
  load_monthly_attendance_health,
  load_pending_legal_case_summary,
  load_people_base,
  ok,
  summarize_ai_insights
} from "../_lib";

export async function GET(request: Request) {
  const schema_version = "portal.ai_insights.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const loaded = await load_people_base(access.ctx, access.scope);
  if (loaded.error) return loaded.error;

  const peopleInsights = compute_people_insights(loaded.employees);
  const [attendance, legal, compliance] = await Promise.all([
    load_monthly_attendance_health(access.ctx, access.scope),
    load_pending_legal_case_summary(access.ctx, access.scope),
    load_compliance_story_summary(access.ctx, access.scope)
  ]);
  const ai_rule_context = {
    attendance_rate: attendance.attendance_rate,
    pending_legal_case_count: legal.pending_case_count,
    pending_compliance_signal_count: compliance.pending_compliance_signal_count,
    expiring_document_30d_count: compliance.expiring_document_30d_count
  };
  const raw_rule_inputs = compute_ai_rule_inputs(peopleInsights, ai_rule_context);
  const rule_inputs = {
    ...raw_rule_inputs,
    completeness_score: raw_rule_inputs.data_completeness_score
  };
  const insights = compute_ai_insights(peopleInsights, ai_rule_context);
  const summary = summarize_ai_insights(insights);

  return ok(schema_version, {
    org_id: access.scope.org_id,
    company_id: access.scope.company_id,
    insights,
    summary,
    rule_inputs,
    source: "rule_based_v1",
    narrative_context: {
      attendance_health: attendance,
      legal_case_summary: legal,
      compliance_summary: compliance
    },
    // camelCase aliases for frontend adapters.
    ruleInputs: {
      ...rule_inputs,
      completenessScore: rule_inputs.completeness_score
    },
    narrativeContext: {
      attendanceHealth: attendance,
      legalCaseSummary: legal,
      complianceSummary: compliance
    }
  });
}

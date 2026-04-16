import { apply_scope, fail } from "../../../hr/_lib";
import {
  compute_ai_insights,
  compute_people_insights,
  ensure_portal_access,
  load_compliance_story_summary,
  load_monthly_attendance_health,
  load_pending_legal_case_summary,
  load_people_base,
  ok
} from "../../_lib";

type Params = {
  params: Promise<{ item_id: string }>;
};

function normalize_severity(value: unknown): "info" | "warning" | "critical" {
  const v = String(value ?? "").toLowerCase();
  if (v === "high" || v === "critical") return "critical";
  if (v === "medium" || v === "warning") return "warning";
  return "info";
}

function parse_item_id(item_id: string) {
  const raw = decodeURIComponent(String(item_id ?? "")).trim();
  const index = raw.indexOf(":");
  if (!raw || index <= 0) return null;
  const kind = raw.slice(0, index);
  const source_id = raw.slice(index + 1);
  if (!source_id) return null;
  return { raw, kind, source_id };
}

export async function GET(request: Request, { params }: Params) {
  const schema_version = "portal.notification_detail.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const { item_id } = await params;
  const parsed = parse_item_id(item_id);
  if (!parsed) return fail(schema_version, "NOTIFICATION_NOT_FOUND", "Notification item not found", 404);

  if (parsed.kind === "warning") {
    const { data: warning, error } = await apply_scope(
      access.ctx.supabase
        .from("leave_compliance_warnings")
        .select("id,warning_type,severity,title,message,is_resolved,created_at,related_rule_ref"),
      access.scope
    )
      .eq("id", parsed.source_id)
      .maybeSingle();
    if (error || !warning) return fail(schema_version, "NOTIFICATION_NOT_FOUND", "Notification item not found", 404);

    const detail = {
      id: parsed.raw,
      item_id: parsed.raw,
      item_type: "compliance_warning",
      source_id: warning.id,
      title: warning.title ?? "Compliance warning",
      status: warning.is_resolved ? "resolved" : "open",
      severity: normalize_severity(warning.severity),
      description: warning.message ?? "",
      trigger_reason: warning.warning_type ?? warning.related_rule_ref ?? "policy_warning",
      event_at: warning.created_at ?? null,
      recommended_action: "Review policy warning details and resolve after verification.",
      admin_route_hint: `/admin/compliance/warnings/${warning.id}`
    };

    return ok(schema_version, {
      org_id: access.scope.org_id,
      company_id: access.scope.company_id,
      detail
    });
  }

  if (parsed.kind === "doc") {
    const { data: doc, error } = await apply_scope(
      access.ctx.supabase
        .from("legal_documents")
        .select("id,document_code,title,signing_status,expiry_date,updated_at"),
      access.scope
    )
      .eq("id", parsed.source_id)
      .maybeSingle();
    if (error || !doc) return fail(schema_version, "NOTIFICATION_NOT_FOUND", "Notification item not found", 404);

    const detail = {
      id: parsed.raw,
      item_id: parsed.raw,
      item_type: "document_expiry_watch",
      source_id: doc.id,
      title: doc.title ?? doc.document_code ?? "Legal document",
      status: doc.signing_status ?? "unknown",
      severity: "warning",
      description: `Document expiry date: ${doc.expiry_date ?? "not set"}.`,
      trigger_reason: `expiry_date=${doc.expiry_date ?? "null"}`,
      event_at: doc.updated_at ?? null,
      recommended_action: "Review renewal/signoff status and update legal document lifecycle.",
      admin_route_hint: `/legal/documents/${doc.id}`
    };

    return ok(schema_version, {
      org_id: access.scope.org_id,
      company_id: access.scope.company_id,
      detail
    });
  }

  if (parsed.kind === "ai") {
    const loaded = await load_people_base(access.ctx, access.scope);
    if (loaded.error) return loaded.error;

    const peopleInsights = compute_people_insights(loaded.employees);
    const [attendance, legal, compliance] = await Promise.all([
      load_monthly_attendance_health(access.ctx, access.scope),
      load_pending_legal_case_summary(access.ctx, access.scope),
      load_compliance_story_summary(access.ctx, access.scope)
    ]);
    const insights = compute_ai_insights(peopleInsights, {
      attendance_rate: attendance.attendance_rate,
      pending_legal_case_count: legal.pending_case_count,
      pending_compliance_signal_count: compliance.pending_compliance_signal_count,
      expiring_document_30d_count: compliance.expiring_document_30d_count
    });
    const insight = insights.find((item) => item.insight_id === parsed.source_id);
    if (!insight) return fail(schema_version, "NOTIFICATION_NOT_FOUND", "Notification item not found", 404);

    const detail = {
      id: parsed.raw,
      item_id: parsed.raw,
      item_type: "ai_insight",
      source_id: insight.insight_id,
      title: insight.title,
      status: "open",
      severity: insight.severity,
      description: insight.message,
      trigger_reason: insight.trigger_reason ?? "rule_based_v1",
      event_at: new Date().toISOString(),
      recommended_action: "Open Portal AI page and review suggested follow-up.",
      admin_route_hint: "/portal/ai"
    };

    return ok(schema_version, {
      org_id: access.scope.org_id,
      company_id: access.scope.company_id,
      detail
    });
  }

  if (parsed.kind === "change") {
    const [employeeRes, departmentRes] = await Promise.all([
      apply_scope(
        access.ctx.supabase
          .from("employees")
          .select("id,employee_code,full_name_local,full_name_latin,display_name,updated_at"),
        access.scope
      ).eq("employee_code", parsed.source_id).maybeSingle(),
      apply_scope(
        access.ctx.supabase
          .from("departments")
          .select("id,department_name,updated_at"),
        access.scope
      ).eq("id", parsed.source_id).maybeSingle()
    ]);

    if (employeeRes.data) {
      const detail = {
        id: parsed.raw,
        item_id: parsed.raw,
        item_type: "employee_updated",
        source_id: employeeRes.data.id,
        title:
          employeeRes.data.full_name_local ??
          employeeRes.data.full_name_latin ??
          employeeRes.data.display_name ??
          employeeRes.data.employee_code ??
          "Employee",
        status: "updated",
        severity: "info",
        description: "Employee profile was recently updated.",
        trigger_reason: `employee_code=${employeeRes.data.employee_code ?? employeeRes.data.id}`,
        event_at: employeeRes.data.updated_at ?? null,
        recommended_action: "Open employee profile and review latest changes.",
        admin_route_hint: `/hr/employees/${employeeRes.data.id}`
      };
      return ok(schema_version, {
        org_id: access.scope.org_id,
        company_id: access.scope.company_id,
        detail
      });
    }

    if (departmentRes.data) {
      const detail = {
        id: parsed.raw,
        item_id: parsed.raw,
        item_type: "department_updated",
        source_id: departmentRes.data.id,
        title: departmentRes.data.department_name ?? "Department",
        status: "updated",
        severity: "info",
        description: "Department profile was recently updated.",
        trigger_reason: `department_id=${departmentRes.data.id}`,
        event_at: departmentRes.data.updated_at ?? null,
        recommended_action: "Open department settings and review latest updates.",
        admin_route_hint: `/hr/departments/${departmentRes.data.id}`
      };
      return ok(schema_version, {
        org_id: access.scope.org_id,
        company_id: access.scope.company_id,
        detail
      });
    }
  }

  return fail(schema_version, "NOTIFICATION_NOT_FOUND", "Notification item not found", 404);
}

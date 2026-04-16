import { apply_scope } from "../../hr/_lib";
import {
  build_recent_changes,
  compute_ai_insights,
  compute_people_insights,
  ensure_portal_access,
  load_compliance_story_summary,
  load_monthly_attendance_health,
  load_pending_legal_case_summary,
  load_people_base,
  ok
} from "../_lib";

type NotificationItem = {
  notification_id: string;
  event_type: string;
  severity: "info" | "warning" | "critical";
  title: string;
  message: string;
  event_at: string | null;
  source: string;
  action_path: string;
  is_read: boolean;
};

function normalize_severity(value: unknown): "info" | "warning" | "critical" {
  const v = String(value ?? "").toLowerCase();
  if (v === "high" || v === "critical") return "critical";
  if (v === "medium" || v === "warning") return "warning";
  return "info";
}

function mk_id(prefix: string, value: string) {
  return `${prefix}:${value}`;
}

export async function GET(request: Request) {
  const schema_version = "portal.notifications.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const loaded = await load_people_base(access.ctx, access.scope);
  if (loaded.error) return loaded.error;

  const people_insights = compute_people_insights(loaded.employees);
  const [attendance, legal, compliance] = await Promise.all([
    load_monthly_attendance_health(access.ctx, access.scope),
    load_pending_legal_case_summary(access.ctx, access.scope),
    load_compliance_story_summary(access.ctx, access.scope)
  ]);
  const ai_insights = compute_ai_insights(people_insights, {
    attendance_rate: attendance.attendance_rate,
    pending_legal_case_count: legal.pending_case_count,
    pending_compliance_signal_count: compliance.pending_compliance_signal_count,
    expiring_document_30d_count: compliance.expiring_document_30d_count
  });
  const recent_changes = build_recent_changes(loaded.employees, loaded.departments);
  const today = new Date();
  const date_today = today.toISOString().slice(0, 10);
  const in30 = new Date(today);
  in30.setUTCDate(in30.getUTCDate() + 30);
  const date_30 = in30.toISOString().slice(0, 10);

  const [documentsRes, warningsRes] = await Promise.all([
    apply_scope(
      access.ctx.supabase
        .from("legal_documents")
        .select("id,document_code,title,expiry_date,updated_at")
        .order("expiry_date", { ascending: true, nullsFirst: false })
        .limit(10),
      access.scope
    ),
    apply_scope(
      access.ctx.supabase
        .from("leave_compliance_warnings")
        .select("id,severity,title,message,created_at,is_resolved")
        .eq("is_resolved", false)
        .order("created_at", { ascending: false })
        .limit(10),
      access.scope
    )
  ]);

  const notifications: NotificationItem[] = [];

  for (const change of recent_changes) {
    notifications.push({
      notification_id: mk_id("change", String(change.ref_id)),
      event_type: String(change.change_type),
      severity: "info",
      title: String(change.title ?? "Update"),
      message: `Recent ${String(change.change_type ?? "change")} detected.`,
      event_at: change.changed_at ?? null,
      source: "portal.recent_changes",
      action_path: "/portal",
      is_read: false
    });
  }

  for (const insight of ai_insights) {
    notifications.push({
      notification_id: mk_id("ai", insight.insight_id),
      event_type: "ai_insight",
      severity: insight.severity,
      title: insight.title,
      message: insight.message,
      event_at: new Date().toISOString(),
      source: "portal.ai_insights",
      action_path: "/portal/ai",
      is_read: false
    });
  }

  for (const d of documentsRes.error ? [] : (documentsRes.data ?? [])) {
    if (!d.expiry_date) continue;
    const expiry = String(d.expiry_date);
    if (!(expiry >= date_today && expiry <= date_30)) continue;
    notifications.push({
      notification_id: mk_id("doc", String(d.id)),
      event_type: "document_expiry_watch",
      severity: "warning",
      title: String(d.title ?? d.document_code ?? "Legal document"),
      message: `Document expiry date: ${String(d.expiry_date)}.`,
      event_at: d.updated_at ?? null,
      source: "portal.compliance",
      action_path: "/portal/compliance",
      is_read: false
    });
  }

  for (const w of warningsRes.error ? [] : (warningsRes.data ?? [])) {
    notifications.push({
      notification_id: mk_id("warning", String(w.id)),
      event_type: "compliance_warning",
      severity: normalize_severity(w.severity),
      title: String(w.title ?? "Compliance warning"),
      message: String(w.message ?? ""),
      event_at: w.created_at ?? null,
      source: "portal.compliance",
      action_path: "/portal/compliance",
      is_read: false
    });
  }

  notifications.sort((a, b) => String(b.event_at ?? "").localeCompare(String(a.event_at ?? "")));

  const summary = {
    total_count: notifications.length,
    warning_count: notifications.filter((n) => n.severity === "warning").length,
    critical_count: notifications.filter((n) => n.severity === "critical").length,
    info_count: notifications.filter((n) => n.severity === "info").length,
    source_counts: {
      recent_changes: notifications.filter((n) => n.source === "portal.recent_changes").length,
      ai_insights: notifications.filter((n) => n.source === "portal.ai_insights").length,
      compliance: notifications.filter((n) => n.source === "portal.compliance").length
    }
  };
  const items = notifications.slice(0, 30).map((item) => ({
    ...item,
    id: item.notification_id,
    item_id: item.notification_id
  }));
  const detail_route_pattern = "/api/portal/notifications/{item_id}";

  return ok(schema_version, {
    org_id: access.scope.org_id,
    company_id: access.scope.company_id,
    summary,
    detail_route_pattern,
    item_ids: items.map((item) => item.notification_id),
    items,
    // camelCase aliases for frontend adapters.
    notifications: items,
    notificationSummary: summary,
    detailRoutePattern: detail_route_pattern,
    itemIds: items.map((item) => item.notification_id)
  });
}

import { apply_scope, type AccessContext, type Scope } from "../../hr/_lib";

export type ComplianceSeverity = "info" | "warning" | "critical";
export type ComplianceItemKind = "warning" | "document" | "case";

type ComplianceItemBase = {
  id: string;
  item_id: string;
  item_type: "compliance_warning" | "document_watch" | "legal_case";
  source_id: string;
  title: string;
  status: string;
  severity: ComplianceSeverity;
  description: string;
  trigger_reason: string;
  due_date: string | null;
  checked_at: string | null;
  affected_count: number;
  related_documents: Array<{ id: string; document_code: string | null; title: string | null }>;
  recommended_action: string;
  admin_route_hint: string;
};

type WarningRow = {
  id: string;
  warning_type: string | null;
  severity: string | null;
  title: string | null;
  message: string | null;
  is_resolved: boolean | null;
  created_at: string | null;
  related_rule_ref?: string | null;
  country_code?: string | null;
};

type DocumentRow = {
  id: string;
  document_code: string | null;
  title: string | null;
  document_type: string | null;
  signing_status: string | null;
  effective_date: string | null;
  expiry_date: string | null;
  updated_at: string | null;
};

type LegalCaseRow = {
  id: string;
  case_code: string | null;
  title: string | null;
  status: string | null;
  risk_level: string | null;
  summary: string | null;
  updated_at: string | null;
};

type LegalCaseDocumentRow = {
  legal_case_id: string;
  legal_documents: {
    id: string;
    document_code: string | null;
    title: string | null;
  } | null;
};

const DOC_PENDING_SIGNOFF_STATUSES = new Set(["draft", "pending", "in_progress", "review"]);
const CLOSED_CASE_STATUSES = new Set(["closed", "resolved", "done", "cancelled", "archived"]);

export function normalize_severity(value: unknown): ComplianceSeverity {
  const v = String(value ?? "").toLowerCase();
  if (v === "high" || v === "critical") return "critical";
  if (v === "medium" || v === "warning") return "warning";
  return "info";
}

export function build_item_id(kind: ComplianceItemKind, id: string) {
  return `${kind}_${id}`;
}

export function parse_item_id(item_id: string): { kind: ComplianceItemKind; source_id: string } | null {
  const raw = decodeURIComponent(String(item_id ?? "")).trim();
  if (!raw) return null;
  if (raw.startsWith("warning_")) return { kind: "warning", source_id: raw.slice("warning_".length) };
  if (raw.startsWith("document_")) return { kind: "document", source_id: raw.slice("document_".length) };
  if (raw.startsWith("case_")) return { kind: "case", source_id: raw.slice("case_".length) };
  return null;
}

function to_iso_date(value: Date) {
  return value.toISOString().slice(0, 10);
}

function document_watch_status(document: DocumentRow, date_today: string, date_30: string) {
  const signing_status = String(document.signing_status ?? "").toLowerCase();
  const expiry_date = document.expiry_date ? String(document.expiry_date) : null;

  if (expiry_date && expiry_date < date_today) return "expired";
  if (expiry_date && expiry_date <= date_30) return "expiring_soon";
  if (DOC_PENDING_SIGNOFF_STATUSES.has(signing_status)) return "pending_signoff";
  return "active";
}

function is_pending_legal_case(status: unknown) {
  const normalized = String(status ?? "").trim().toLowerCase();
  if (!normalized) return true;
  return !CLOSED_CASE_STATUSES.has(normalized);
}

function warning_to_detail(row: WarningRow): ComplianceItemBase {
  const id = build_item_id("warning", row.id);
  const status = row.is_resolved ? "resolved" : "open";
  return {
    id,
    item_id: id,
    item_type: "compliance_warning",
    source_id: row.id,
    title: String(row.title ?? "Compliance warning"),
    status,
    severity: normalize_severity(row.severity),
    description: String(row.message ?? ""),
    trigger_reason: String(row.warning_type ?? row.related_rule_ref ?? "policy_warning"),
    due_date: null,
    checked_at: row.created_at ?? null,
    affected_count: 1,
    related_documents: [],
    recommended_action: "Review warning details and mark as resolved after policy verification.",
    admin_route_hint: `/admin/compliance/warnings/${row.id}`
  };
}

function document_to_detail(
  row: DocumentRow,
  related_documents: Array<{ id: string; document_code: string | null; title: string | null }>,
  date_today: string,
  date_30: string
): ComplianceItemBase {
  const id = build_item_id("document", row.id);
  const status = document_watch_status(row, date_today, date_30);
  const severity: ComplianceSeverity =
    status === "expired" ? "critical" : status === "active" ? "info" : "warning";

  return {
    id,
    item_id: id,
    item_type: "document_watch",
    source_id: row.id,
    title: String(row.title ?? row.document_code ?? "Legal document"),
    status,
    severity,
    description:
      status === "pending_signoff"
        ? "Document is waiting for signoff."
        : `Document expiry date is ${row.expiry_date ?? "not set"}.`,
    trigger_reason: `document_type=${String(row.document_type ?? "unknown")}; signing_status=${String(row.signing_status ?? "unknown")}`,
    due_date: row.expiry_date ?? null,
    checked_at: row.updated_at ?? null,
    affected_count: Math.max(related_documents.length, 1),
    related_documents,
    recommended_action:
      status === "pending_signoff"
        ? "Complete review/signoff workflow and confirm final signed version."
        : "Plan renewal and verify latest legal terms before expiry.",
    admin_route_hint: `/legal/documents/${row.id}`
  };
}

function case_to_detail(
  row: LegalCaseRow,
  related_documents: Array<{ id: string; document_code: string | null; title: string | null }>
): ComplianceItemBase {
  const id = build_item_id("case", row.id);
  return {
    id,
    item_id: id,
    item_type: "legal_case",
    source_id: row.id,
    title: String(row.title ?? row.case_code ?? "Legal case"),
    status: String(row.status ?? "unknown"),
    severity: normalize_severity(row.risk_level),
    description: String(row.summary ?? "Legal case follow-up is required."),
    trigger_reason: `legal_case_status=${String(row.status ?? "unknown")}`,
    due_date: null,
    checked_at: row.updated_at ?? null,
    affected_count: Math.max(related_documents.length, 1),
    related_documents,
    recommended_action: "Review case timeline and owner assignment in Legal Console.",
    admin_route_hint: `/legal/cases/${row.id}`
  };
}

function group_case_documents(rows: LegalCaseDocumentRow[]) {
  const grouped = new Map<string, Array<{ id: string; document_code: string | null; title: string | null }>>();
  for (const row of rows ?? []) {
    if (!row.legal_case_id) continue;
    const list = grouped.get(row.legal_case_id) ?? [];
    if (row.legal_documents?.id) {
      list.push({
        id: row.legal_documents.id,
        document_code: row.legal_documents.document_code ?? null,
        title: row.legal_documents.title ?? null
      });
    }
    grouped.set(row.legal_case_id, list);
  }
  return grouped;
}

export async function load_compliance_summary_dataset(ctx: AccessContext, scope: Scope) {
  const today = new Date();
  const date_today = to_iso_date(today);
  const in30 = new Date(today);
  in30.setUTCDate(in30.getUTCDate() + 30);
  const date_30 = to_iso_date(in30);

  const [documentsRes, warningsRes, legalCasesRes, caseDocsRes] = await Promise.all([
    apply_scope(
      ctx.supabase
        .from("legal_documents")
        .select("id,document_code,title,document_type,signing_status,effective_date,expiry_date,updated_at")
        .order("expiry_date", { ascending: true, nullsFirst: false }),
      scope
    ),
    apply_scope(
      ctx.supabase
        .from("leave_compliance_warnings")
        .select("id,warning_type,severity,title,message,is_resolved,created_at,related_rule_ref,country_code")
        .eq("is_resolved", false)
        .order("created_at", { ascending: false })
        .limit(30),
      scope
    ),
    apply_scope(
      ctx.supabase
        .from("legal_cases")
        .select("id,case_code,title,status,risk_level,summary,updated_at")
        .order("updated_at", { ascending: false }),
      scope
    ),
    apply_scope(
      ctx.supabase
        .from("legal_case_documents")
        .select("legal_case_id,legal_documents(id,document_code,title)"),
      scope
    )
  ]);

  const documents: DocumentRow[] = documentsRes.error ? [] : (documentsRes.data ?? []);
  const warnings: WarningRow[] = warningsRes.error ? [] : (warningsRes.data ?? []);
  const legal_cases: LegalCaseRow[] = legalCasesRes.error ? [] : (legalCasesRes.data ?? []);
  const case_documents: LegalCaseDocumentRow[] = caseDocsRes.error ? [] : (caseDocsRes.data ?? []);

  const case_document_map = group_case_documents(case_documents);
  const expiring_documents = documents.filter((d) => {
    if (!d.expiry_date) return false;
    const date = String(d.expiry_date);
    return date >= date_today && date <= date_30;
  });
  const expired_documents = documents.filter((d) => {
    if (!d.expiry_date) return false;
    return String(d.expiry_date) < date_today;
  });
  const pending_signoff_documents = documents.filter((d) =>
    DOC_PENDING_SIGNOFF_STATUSES.has(String(d.signing_status ?? "").toLowerCase())
  );
  const pending_legal_cases = legal_cases.filter((c) => is_pending_legal_case(c.status));
  const pending_compliance_signals = warnings.map((w) => ({
    signal_id: w.id,
    signal_type: String(w.warning_type ?? "policy_warning"),
    severity: normalize_severity(w.severity),
    title: String(w.title ?? "Compliance warning"),
    message: String(w.message ?? ""),
    created_at: w.created_at ?? null
  }));

  const warning_items = warnings.map((w) => warning_to_detail(w));
  const document_items = documents
    .filter((doc) => document_watch_status(doc, date_today, date_30) !== "active")
    .map((doc) =>
      document_to_detail(
        doc,
        [{ id: doc.id, document_code: doc.document_code ?? null, title: doc.title ?? null }],
        date_today,
        date_30
      )
    );
  const case_items = pending_legal_cases.map((c) => case_to_detail(c, case_document_map.get(c.id) ?? []));
  const items = [...warning_items, ...document_items, ...case_items].sort((a, b) =>
    String(b.checked_at ?? b.due_date ?? "").localeCompare(String(a.checked_at ?? a.due_date ?? ""))
  );

  const summary = {
    total_items: items.length,
    critical_count: items.filter((item) => item.severity === "critical").length,
    warning_count: items.filter((item) => item.severity === "warning").length,
    info_count: items.filter((item) => item.severity === "info").length,
    pending_compliance_signal_count: pending_compliance_signals.length,
    pending_legal_case_count: pending_legal_cases.length,
    expiring_document_count: expiring_documents.length
  };

  const document_summary = {
    total_documents: documents.length,
    expiring_30d_count: expiring_documents.length,
    expired_count: expired_documents.length,
    pending_signoff_count: pending_signoff_documents.length
  };

  return {
    date_today,
    date_30,
    documents,
    warnings,
    legal_cases,
    case_document_map,
    document_summary,
    expiring_documents,
    pending_compliance_signals,
    pending_legal_cases,
    items,
    summary
  };
}

export async function load_compliance_detail_item(
  ctx: AccessContext,
  scope: Scope,
  item_id: string
) {
  const parsed = parse_item_id(item_id);
  const raw_id = decodeURIComponent(String(item_id ?? "")).trim();
  const candidate_id = parsed?.source_id ?? raw_id;

  const today = new Date();
  const date_today = to_iso_date(today);
  const in30 = new Date(today);
  in30.setUTCDate(in30.getUTCDate() + 30);
  const date_30 = to_iso_date(in30);

  const load_warning = async (id: string) => {
    const { data, error } = await apply_scope(
      ctx.supabase
        .from("leave_compliance_warnings")
        .select("id,warning_type,severity,title,message,is_resolved,created_at,related_rule_ref,country_code"),
      scope
    )
      .eq("id", id)
      .maybeSingle();
    if (error || !data) return null;
    return warning_to_detail(data as WarningRow);
  };

  const load_document = async (id: string) => {
    const { data, error } = await apply_scope(
      ctx.supabase
        .from("legal_documents")
        .select("id,document_code,title,document_type,signing_status,effective_date,expiry_date,updated_at"),
      scope
    )
      .eq("id", id)
      .maybeSingle();
    if (error || !data) return null;
    return document_to_detail(
      data as DocumentRow,
      [{ id: data.id, document_code: data.document_code ?? null, title: data.title ?? null }],
      date_today,
      date_30
    );
  };

  const load_case = async (id: string) => {
    const [{ data: legal_case, error: case_error }, { data: linked_docs, error: docs_error }] = await Promise.all([
      apply_scope(
        ctx.supabase
          .from("legal_cases")
          .select("id,case_code,title,status,risk_level,summary,updated_at"),
        scope
      )
        .eq("id", id)
        .maybeSingle(),
      apply_scope(
        ctx.supabase
          .from("legal_case_documents")
          .select("legal_case_id,legal_documents(id,document_code,title)"),
        scope
      ).eq("legal_case_id", id)
    ]);
    if (case_error || !legal_case) return null;
    const related_documents = docs_error
      ? []
      : (linked_docs ?? [])
          .map((row: any) => row?.legal_documents)
          .filter((doc: any) => !!doc?.id)
          .map((doc: any) => ({
            id: doc.id,
            document_code: doc.document_code ?? null,
            title: doc.title ?? null
          }));
    return case_to_detail(legal_case as LegalCaseRow, related_documents);
  };

  if (parsed?.kind === "warning") return await load_warning(parsed.source_id);
  if (parsed?.kind === "document") return await load_document(parsed.source_id);
  if (parsed?.kind === "case") return await load_case(parsed.source_id);

  const warning = await load_warning(candidate_id);
  if (warning) return warning;
  const document = await load_document(candidate_id);
  if (document) return document;
  return await load_case(candidate_id);
}

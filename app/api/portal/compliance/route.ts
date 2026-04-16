import { load_compliance_summary_dataset } from "./_lib";
import { ensure_portal_access, ok } from "../_lib";

export async function GET(request: Request) {
  const schema_version = "portal.compliance.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const dataset = await load_compliance_summary_dataset(access.ctx, access.scope);
  const items = dataset.items.slice(0, 50);
  const detail_route_pattern = "/api/portal/compliance/{item_id}";

  return ok(schema_version, {
    org_id: access.scope.org_id,
    company_id: access.scope.company_id,
    document_summary: dataset.document_summary,
    pending_compliance_signal_count: dataset.pending_compliance_signals.length,
    pending_legal_case_count: dataset.pending_legal_cases.length,
    expiring_documents: dataset.expiring_documents.slice(0, 10),
    pending_compliance_signals: dataset.pending_compliance_signals,
    item_ids: items.map((item) => item.item_id),
    items,
    detail_route_pattern,
    summary: {
      ...dataset.summary,
      document_summary: dataset.document_summary
    },
    // camelCase aliases for frontend adapters.
    documentSummary: dataset.document_summary,
    pendingComplianceSignalCount: dataset.pending_compliance_signals.length,
    pendingLegalCaseCount: dataset.pending_legal_cases.length,
    expiringDocuments: dataset.expiring_documents.slice(0, 10),
    pendingComplianceSignals: dataset.pending_compliance_signals,
    itemIds: items.map((item) => item.item_id),
    detailRoutePattern: detail_route_pattern
  });
}

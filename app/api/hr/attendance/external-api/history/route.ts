import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_read,
  parse_pagination
} from "../../../_lib";
import { get_service_supabase } from "../_lib";

export async function GET(request: Request) {
  const schema_version = "hr.attendance.external.history.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const url = new URL(request.url);
  const source_registry_id = url.searchParams.get("source_registry_id");
  const { page, page_size, from, to } = parse_pagination(request);

  let query = service
    .from("attendance_import_batches")
    .select(
      "id,source_registry_id,source_type,sync_mode,file_name,file_type,status,total_rows,valid_rows,invalid_rows,duplicate_rows,imported_rows,created_at,updated_at",
      { count: "exact" }
    )
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .eq("source_type", "external_api");

  if (source_registry_id) query = query.eq("source_registry_id", source_registry_id);

  const { data: batches, count, error } = await query
    .order("created_at", { ascending: false })
    .range(from, to);

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch external import history", 500);

  const batch_ids = (batches ?? []).map((batch) => batch.id);
  const source_ids = Array.from(
    new Set((batches ?? []).map((batch) => batch.source_registry_id).filter((value): value is string => !!value))
  );

  const [{ data: sources }, { data: audits }] = await Promise.all([
    source_ids.length > 0
      ? service
          .from("attendance_source_registry")
          .select("id,source_key,source_name,auth_mode,is_enabled,last_validated_at")
          .in("id", source_ids)
      : Promise.resolve({ data: [] as any[] }),
    batch_ids.length > 0
      ? service
          .from("attendance_external_event_audits")
          .select("batch_id,result_status,created_at,event_id,source_ref,failure_code")
          .in("batch_id", batch_ids)
          .order("created_at", { ascending: false })
      : Promise.resolve({ data: [] as any[] })
  ]);

  const source_map = new Map((sources ?? []).map((source) => [source.id, source]));
  const audit_by_batch = new Map<string, any[]>();
  for (const audit of audits ?? []) {
    const key = String(audit.batch_id);
    if (!audit_by_batch.has(key)) audit_by_batch.set(key, []);
    audit_by_batch.get(key)!.push(audit);
  }

  const items = (batches ?? []).map((batch) => {
    const source = batch.source_registry_id ? source_map.get(batch.source_registry_id) ?? null : null;
    const audit_rows = audit_by_batch.get(batch.id) ?? [];
    const summary = {
      preview_valid: audit_rows.filter((row) => row.result_status === "preview_valid").length,
      preview_error: audit_rows.filter((row) => row.result_status === "preview_error").length,
      duplicate: audit_rows.filter((row) => row.result_status === "duplicate").length,
      imported: audit_rows.filter((row) => row.result_status === "imported").length,
      failed: audit_rows.filter((row) => row.result_status === "failed").length,
      rejected: audit_rows.filter((row) => row.result_status === "rejected").length
    };
    return {
      ...batch,
      source,
      audit_summary: summary,
      recent_events: audit_rows.slice(0, 10).map((row) => ({
        created_at: row.created_at,
        result_status: row.result_status,
        event_id: row.event_id,
        source_ref: row.source_ref,
        failure_code: row.failure_code
      }))
    };
  });

  return ok(schema_version, {
    items,
    pagination: {
      page,
      page_size,
      total: count ?? 0
    }
  });
}

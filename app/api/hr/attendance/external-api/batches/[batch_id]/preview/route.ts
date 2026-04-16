import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_read
} from "../../../../../_lib";
import { get_service_supabase } from "../../../_lib";

export async function GET(
  request: Request,
  { params }: { params: { batch_id: string } }
) {
  const schema_version = "hr.attendance.external.preview.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const batch_id = params.batch_id;
  if (!batch_id) return fail(schema_version, "INVALID_REQUEST", "batch_id is required", 400);

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const { data: batch, error: batch_error } = await service
    .from("attendance_import_batches")
    .select("id,source_type,source_registry_id,file_name,file_type,status,total_rows,valid_rows,invalid_rows,duplicate_rows,imported_rows,created_at,updated_at")
    .eq("id", batch_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .eq("source_type", "external_api")
    .maybeSingle();

  if (batch_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch import batch", 500);
  if (!batch) return fail(schema_version, "BATCH_NOT_FOUND", "External import batch not found", 404);

  const [{ data: rows, error: rows_error }, { data: source, error: source_error }] = await Promise.all([
    service
      .from("attendance_import_rows")
      .select("id,row_index,event_id,source_ref,employee_code,external_employee_ref,attendance_date,check_type,checked_at,branch_id,status,error_code,error_message,is_duplicate,is_corrected,review_note,created_at,updated_at")
      .eq("batch_id", batch.id)
      .order("row_index", { ascending: true }),
    batch.source_registry_id
      ? service
          .from("attendance_source_registry")
          .select("id,source_key,source_name,auth_mode,is_enabled,last_validated_at")
          .eq("id", batch.source_registry_id)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null })
  ]);

  if (rows_error || source_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch preview data", 500);
  }

  return ok(schema_version, {
    source: source ?? null,
    batch,
    summary: {
      total_rows: batch.total_rows,
      valid_rows: batch.valid_rows,
      invalid_rows: batch.invalid_rows,
      duplicate_rows: batch.duplicate_rows,
      imported_rows: batch.imported_rows
    },
    preview: rows ?? []
  });
}

import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_read,
  parse_pagination
} from "../../_lib";
import { get_service_supabase } from "./_lib";

export async function GET(request: Request) {
  const schema_version = "hr.attendance.import.batch.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const { page, page_size, from, to } = parse_pagination(request);
  const { data, count, error } = await service
    .from("attendance_import_batches")
    .select(
      "id,source_type,file_name,file_type,status,total_rows,valid_rows,invalid_rows,duplicate_rows,imported_rows,created_at,updated_at,created_by,updated_by",
      { count: "exact" }
    )
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .order("created_at", { ascending: false })
    .range(from, to);

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch import history", 500);

  return ok(schema_version, {
    items: data ?? [],
    pagination: {
      page,
      page_size,
      total: count ?? 0
    }
  });
}

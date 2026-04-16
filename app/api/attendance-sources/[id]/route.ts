import { get_scoped_context, success, failure, parse_json_body, to_bool } from "../../_attendance_phase1";

type Params = { params: { id: string } };

export async function PATCH(request: Request, { params }: Params) {
  const rawBody = await request.text();
  const body = parse_json_body(rawBody);
  if (body === null) return failure("INVALID_JSON", "Request body must be valid JSON", 400);

  const scoped = await get_scoped_context(request, { write: true, body });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const source_id = params.id;
  if (!source_id) return failure("INVALID_REQUEST", "source id is required", 400);

  const updates: Record<string, unknown> = {};
  if ("is_enabled" in body) {
    const parsed = to_bool(body.is_enabled);
    if (parsed === null) return failure("INVALID_REQUEST", "is_enabled must be boolean", 400);
    updates.is_enabled = parsed;
  }
  if ("config" in body) {
    if (body.config && typeof body.config === "object" && !Array.isArray(body.config)) {
      updates.config = body.config;
    } else {
      return failure("INVALID_REQUEST", "config must be an object", 400);
    }
  }
  if (Object.keys(updates).length === 0) {
    return failure("INVALID_REQUEST", "No patchable field provided", 400);
  }

  const { data: existing, error: find_error } = await ctx.supabase
    .from("attendance_sources")
    .select("id")
    .eq("id", source_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .maybeSingle();
  if (find_error) return failure("INTERNAL_ERROR", "Failed to fetch attendance source", 500);
  if (!existing) return failure("ATTENDANCE_SOURCE_NOT_FOUND", "Attendance source not found in current scope", 404);

  const { data, error } = await ctx.supabase
    .from("attendance_sources")
    .update(updates)
    .eq("id", source_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .select("id,org_id,company_id,source_key,is_enabled,config,created_at,updated_at")
    .maybeSingle();
  if (error) return failure("INTERNAL_ERROR", "Failed to update attendance source", 500, { detail: error.message });

  return success({ item: data });
}

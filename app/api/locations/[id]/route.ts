import { get_scoped_context, success, failure, parse_json_body, to_bool, to_number } from "../../_attendance_phase1";

type Params = { params: { id: string } };

export async function PATCH(request: Request, { params }: Params) {
  const rawBody = await request.text();
  const body = parse_json_body(rawBody);
  if (body === null) return failure("INVALID_JSON", "Request body must be valid JSON", 400);

  const scoped = await get_scoped_context(request, { write: true, body });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const location_id = params.id;
  if (!location_id) return failure("INVALID_REQUEST", "location id is required", 400);

  const updates: Record<string, unknown> = {};
  if (typeof body.code === "string") updates.code = body.code.trim() || null;
  if (typeof body.name === "string") updates.name = body.name.trim();
  if (typeof body.address === "string") updates.address = body.address.trim() || null;
  if ("latitude" in body) updates.latitude = to_number(body.latitude);
  if ("longitude" in body) updates.longitude = to_number(body.longitude);
  if ("checkin_radius_m" in body) updates.checkin_radius_m = to_number(body.checkin_radius_m);
  if ("is_attendance_enabled" in body) updates.is_attendance_enabled = to_bool(body.is_attendance_enabled);
  if ("is_active" in body) updates.is_active = to_bool(body.is_active);
  if ("notes" in body) updates.notes = typeof body.notes === "string" ? body.notes : null;

  const normalized = Object.fromEntries(
    Object.entries(updates).filter(([, value]) => value !== undefined)
  );
  if (Object.keys(normalized).length === 0) {
    return failure("INVALID_REQUEST", "No patchable field provided", 400);
  }

  const { data: existing, error: find_error } = await ctx.supabase
    .from("locations")
    .select("id")
    .eq("id", location_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .maybeSingle();
  if (find_error) return failure("INTERNAL_ERROR", "Failed to fetch location", 500);
  if (!existing) return failure("LOCATION_NOT_FOUND", "Location not found in current scope", 404);

  const { data, error } = await ctx.supabase
    .from("locations")
    .update(normalized)
    .eq("id", location_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .select("id,org_id,company_id,code,name,address,latitude,longitude,checkin_radius_m,is_attendance_enabled,is_active,notes,created_at,updated_at")
    .maybeSingle();

  if (error) return failure("INTERNAL_ERROR", "Failed to update location", 500, { detail: error.message });
  return success({ item: data });
}

import { get_scoped_context, success, failure, parse_json_body, to_bool, to_number } from "../_attendance_phase1";

export async function GET(request: Request) {
  const scoped = await get_scoped_context(request, { write: false });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const url = new URL(request.url);
  const is_active = to_bool(url.searchParams.get("is_active"));

  let query = ctx.supabase
    .from("locations")
    .select("id,org_id,company_id,code,name,address,latitude,longitude,checkin_radius_m,is_attendance_enabled,is_active,notes,created_at,updated_at")
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .order("created_at", { ascending: true });

  if (is_active !== null) query = query.eq("is_active", is_active);

  const { data, error } = await query;
  if (error) return failure("INTERNAL_ERROR", "Failed to fetch locations", 500);

  return success({
    org_id: scope.org_id,
    company_id: scope.company_id,
    items: data ?? []
  });
}

export async function POST(request: Request) {
  const rawBody = await request.text();
  const body = parse_json_body(rawBody);
  if (body === null) return failure("INVALID_JSON", "Request body must be valid JSON", 400);

  const scoped = await get_scoped_context(request, { write: true, body });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const name = typeof body.name === "string" ? body.name.trim() : "";
  if (!name) return failure("INVALID_REQUEST", "name is required", 400);

  const payload = {
    org_id: scope.org_id,
    company_id: scope.company_id,
    code: typeof body.code === "string" ? body.code.trim() || null : null,
    name,
    address: typeof body.address === "string" ? body.address.trim() || null : null,
    latitude: to_number(body.latitude),
    longitude: to_number(body.longitude),
    checkin_radius_m: to_number(body.checkin_radius_m),
    is_attendance_enabled: to_bool(body.is_attendance_enabled) ?? true,
    is_active: to_bool(body.is_active) ?? true,
    notes: typeof body.notes === "string" ? body.notes : null
  };

  const { data, error } = await ctx.supabase
    .from("locations")
    .insert(payload)
    .select("id,org_id,company_id,code,name,address,latitude,longitude,checkin_radius_m,is_attendance_enabled,is_active,notes,created_at,updated_at")
    .maybeSingle();

  if (error) return failure("INTERNAL_ERROR", "Failed to create location", 500, { detail: error.message });
  return success({ item: data }, 201);
}

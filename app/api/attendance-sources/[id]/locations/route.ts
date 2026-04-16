import { get_scoped_context, success, failure, parse_json_body } from "../../../_attendance_phase1";

type Params = { params: { id: string } };

async function fetch_source_with_locations(ctx: any, scope: { org_id: string; company_id: string }, source_id: string) {
  const [{ data: source, error: source_error }, { data: locations, error: location_error }, { data: bindings, error: binding_error }] =
    await Promise.all([
      ctx.supabase
        .from("attendance_sources")
        .select("id,org_id,company_id,source_key,is_enabled,config,created_at,updated_at")
        .eq("id", source_id)
        .eq("org_id", scope.org_id)
        .eq("company_id", scope.company_id)
        .maybeSingle(),
      ctx.supabase
        .from("locations")
        .select("id,code,name,address,is_attendance_enabled,is_active,checkin_radius_m")
        .eq("org_id", scope.org_id)
        .eq("company_id", scope.company_id)
        .order("created_at", { ascending: true }),
      ctx.supabase
        .from("attendance_source_location_bindings")
        .select("id,attendance_source_id,location_id,is_enabled,created_at")
        .eq("org_id", scope.org_id)
        .eq("company_id", scope.company_id)
        .eq("attendance_source_id", source_id)
    ]);

  if (source_error || location_error || binding_error) {
    return { source: null, items: null, error: source_error?.message ?? location_error?.message ?? binding_error?.message ?? "Unknown error" };
  }
  if (!source) return { source: null, items: null, error: "ATTENDANCE_SOURCE_NOT_FOUND" };

  const binding_map = new Map(((bindings ?? []) as any[]).map((b) => [b.location_id as string, b]));
  const items = ((locations ?? []) as any[]).map((loc) => {
    const binding = binding_map.get(loc.id);
    return {
      location_id: loc.id,
      location_code: loc.code,
      location_name: loc.name,
      location_address: loc.address,
      location_is_attendance_enabled: loc.is_attendance_enabled,
      location_is_active: loc.is_active,
      location_checkin_radius_m: loc.checkin_radius_m,
      binding_id: binding?.id ?? null,
      is_bound: Boolean(binding),
      is_enabled: binding?.is_enabled ?? false,
      bound_at: binding?.created_at ?? null
    };
  });

  return { source, items, error: null };
}

export async function GET(request: Request, { params }: Params) {
  const scoped = await get_scoped_context(request, { write: false });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const source_id = params.id;
  if (!source_id) return failure("INVALID_REQUEST", "source id is required", 400);

  const { source, items, error } = await fetch_source_with_locations(ctx, scope, source_id);
  if (error === "ATTENDANCE_SOURCE_NOT_FOUND") {
    return failure("ATTENDANCE_SOURCE_NOT_FOUND", "Attendance source not found in current scope", 404);
  }
  if (error) return failure("INTERNAL_ERROR", "Failed to fetch attendance source locations", 500, { detail: error });

  return success({ source, items });
}

export async function PUT(request: Request, { params }: Params) {
  const rawBody = await request.text();
  const body = parse_json_body(rawBody);
  if (body === null) return failure("INVALID_JSON", "Request body must be valid JSON", 400);

  const scoped = await get_scoped_context(request, { write: true, body });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const source_id = params.id;
  if (!source_id) return failure("INVALID_REQUEST", "source id is required", 400);

  const location_ids = Array.isArray(body.location_ids)
    ? Array.from(new Set(body.location_ids.filter((id): id is string => typeof id === "string" && !!id)))
    : null;
  if (!location_ids) return failure("INVALID_REQUEST", "location_ids must be an array of location id", 400);

  const { data: source, error: source_error } = await ctx.supabase
    .from("attendance_sources")
    .select("id")
    .eq("id", source_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .maybeSingle();
  if (source_error) return failure("INTERNAL_ERROR", "Failed to fetch attendance source", 500);
  if (!source) return failure("ATTENDANCE_SOURCE_NOT_FOUND", "Attendance source not found in current scope", 404);

  if (location_ids.length > 0) {
    const { data: valid_locations, error: location_error } = await ctx.supabase
      .from("locations")
      .select("id")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .in("id", location_ids);
    if (location_error) return failure("INTERNAL_ERROR", "Failed to validate locations", 500);

    const valid_ids = new Set((valid_locations ?? []).map((row) => row.id as string));
    const invalid_ids = location_ids.filter((id) => !valid_ids.has(id));
    if (invalid_ids.length > 0) {
      return failure("INVALID_REQUEST", "Some location_ids are out of scope", 400, { invalid_location_ids: invalid_ids });
    }
  }

  const { error: disable_error } = await ctx.supabase
    .from("attendance_source_location_bindings")
    .update({ is_enabled: false })
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("attendance_source_id", source_id);
  if (disable_error) return failure("INTERNAL_ERROR", "Failed to update attendance source location bindings", 500);

  if (location_ids.length > 0) {
    const rows = location_ids.map((location_id) => ({
      org_id: scope.org_id,
      company_id: scope.company_id,
      attendance_source_id: source_id,
      location_id,
      is_enabled: true
    }));
    const { error: upsert_error } = await ctx.supabase
      .from("attendance_source_location_bindings")
      .upsert(rows, { onConflict: "attendance_source_id,location_id" });
    if (upsert_error) {
      return failure("INTERNAL_ERROR", "Failed to bind locations to attendance source", 500, { detail: upsert_error.message });
    }
  }

  const { source: refreshed_source, items, error } = await fetch_source_with_locations(ctx, scope, source_id);
  if (error) return failure("INTERNAL_ERROR", "Failed to fetch updated attendance source locations", 500, { detail: error });

  return success({
    source: refreshed_source,
    items: items ?? [],
    enabled_count: (items ?? []).filter((item) => item.is_enabled).length
  });
}

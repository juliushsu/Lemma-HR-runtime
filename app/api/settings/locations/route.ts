import { ok, fail, get_access_context, resolve_scope, can_read, apply_scope } from "../../hr/_lib";

export async function GET(request: Request) {
  const schema_version = "settings.location.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const url = new URL(request.url);
  const branch_id = url.searchParams.get("branch_id");

  let branch_query = apply_scope(
    ctx.supabase
      .from("branches")
      .select("id,name,latitude,longitude,is_attendance_enabled")
      .order("created_at", { ascending: true }),
    scope
  );
  if (branch_id) branch_query = branch_query.eq("id", branch_id);

  const [{ data: branches, error: branch_error }, { data: boundaries, error: boundary_error }] = await Promise.all([
    branch_query,
    apply_scope(
      ctx.supabase.from("attendance_boundary_settings").select("branch_id,checkin_radius_m,is_attendance_enabled"),
      scope
    )
  ]);

  if (branch_error || boundary_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch locations", 500);
  }

  const company_default = (boundaries ?? []).find((b) => !b.branch_id) ?? null;
  const branch_boundary_map = new Map(
    (boundaries ?? [])
      .filter((b) => !!b.branch_id)
      .map((b) => [b.branch_id as string, { checkin_radius_m: b.checkin_radius_m, is_attendance_enabled: b.is_attendance_enabled }])
  );

  const items = (branches ?? []).map((branch) => {
    const boundary = branch_boundary_map.get(branch.id) ?? null;
    return {
      branch_id: branch.id,
      location_name: branch.name,
      latitude: branch.latitude,
      longitude: branch.longitude,
      checkin_radius_m: boundary?.checkin_radius_m ?? company_default?.checkin_radius_m ?? null,
      is_attendance_enabled:
        boundary?.is_attendance_enabled ?? branch.is_attendance_enabled ?? company_default?.is_attendance_enabled ?? true
    };
  });

  return ok(schema_version, { items });
}

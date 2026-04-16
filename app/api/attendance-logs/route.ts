import { get_scoped_context, success, failure, to_number } from "../_attendance_phase1";

export async function GET(request: Request) {
  const scoped = await get_scoped_context(request, { write: false });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const url = new URL(request.url);
  const employee_id = url.searchParams.get("employee_id");
  const location_id = url.searchParams.get("location_id");
  const attendance_source_id = url.searchParams.get("attendance_source_id");
  const source_key = url.searchParams.get("source_key");
  const check_type = url.searchParams.get("check_type");
  const date_from = url.searchParams.get("date_from");
  const date_to = url.searchParams.get("date_to");
  const page = Math.max(1, Number(url.searchParams.get("page") ?? "1"));
  const page_size = Math.min(100, Math.max(1, Number(url.searchParams.get("page_size") ?? "20")));
  const from = (page - 1) * page_size;
  const to = from + page_size - 1;

  let query = ctx.supabase
    .from("attendance_logs")
    .select(
      "id,org_id,company_id,employee_id,location_id,attendance_source_id,source_key,check_type,checked_at,gps_latitude,gps_longitude,distance_m,is_within_range,record_source,status_color,is_valid,raw_payload,notes,created_at,updated_at",
      { count: "exact" }
    )
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type);

  if (employee_id) query = query.eq("employee_id", employee_id);
  if (location_id) query = query.eq("location_id", location_id);
  if (attendance_source_id) query = query.eq("attendance_source_id", attendance_source_id);
  if (source_key) query = query.eq("source_key", source_key);
  if (check_type) query = query.eq("check_type", check_type);
  if (date_from) query = query.gte("checked_at", date_from);
  if (date_to) query = query.lte("checked_at", date_to);

  const { data: logs, count, error } = await query.order("checked_at", { ascending: false }).range(from, to);
  if (error) return failure("INTERNAL_ERROR", "Failed to fetch attendance logs", 500, { detail: error.message });

  const employee_ids = Array.from(new Set((logs ?? []).map((row) => row.employee_id).filter(Boolean)));
  const location_ids = Array.from(new Set((logs ?? []).map((row) => row.location_id).filter(Boolean)));
  const source_ids = Array.from(new Set((logs ?? []).map((row) => row.attendance_source_id).filter(Boolean)));

  const [{ data: employees }, { data: locations }, { data: sources }] = await Promise.all([
    employee_ids.length
      ? ctx.supabase
          .from("employees")
          .select("id,employee_code,display_name,preferred_name,legal_name")
          .eq("org_id", scope.org_id)
          .eq("company_id", scope.company_id)
          .in("id", employee_ids)
      : Promise.resolve({ data: [] }),
    location_ids.length
      ? ctx.supabase
          .from("locations")
          .select("id,code,name")
          .eq("org_id", scope.org_id)
          .eq("company_id", scope.company_id)
          .in("id", location_ids)
      : Promise.resolve({ data: [] }),
    source_ids.length
      ? ctx.supabase
          .from("attendance_sources")
          .select("id,source_key,is_enabled")
          .eq("org_id", scope.org_id)
          .eq("company_id", scope.company_id)
          .in("id", source_ids)
      : Promise.resolve({ data: [] })
  ]);

  const employee_map = new Map(((employees ?? []) as any[]).map((row) => [row.id as string, row]));
  const location_map = new Map(((locations ?? []) as any[]).map((row) => [row.id as string, row]));
  const source_map = new Map(((sources ?? []) as any[]).map((row) => [row.id as string, row]));

  const items = (logs ?? []).map((row) => {
    const employee = employee_map.get(row.employee_id);
    const location = row.location_id ? location_map.get(row.location_id) : null;
    const source = row.attendance_source_id ? source_map.get(row.attendance_source_id) : null;
    return {
      id: row.id,
      checked_at: row.checked_at,
      check_type: row.check_type,
      employee_id: row.employee_id,
      employee_code: employee?.employee_code ?? null,
      employee_name: employee?.display_name ?? employee?.preferred_name ?? employee?.legal_name ?? null,
      location_id: row.location_id,
      location_code: location?.code ?? null,
      location_name: location?.name ?? null,
      attendance_source_id: row.attendance_source_id,
      source_key: row.source_key ?? source?.source_key ?? null,
      source_is_enabled: source?.is_enabled ?? null,
      gps_latitude: to_number(row.gps_latitude),
      gps_longitude: to_number(row.gps_longitude),
      distance_m: to_number(row.distance_m),
      is_within_range: row.is_within_range,
      status_color: row.status_color,
      is_valid: row.is_valid,
      record_source: row.record_source,
      notes: row.notes,
      raw_payload: row.raw_payload ?? {}
    };
  });

  return success({
    org_id: scope.org_id,
    company_id: scope.company_id,
    items,
    pagination: {
      page,
      page_size,
      total: count ?? 0
    }
  });
}

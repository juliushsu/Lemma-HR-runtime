import { ok, fail, get_access_context, resolve_scope, can_read, apply_scope, parse_pagination, get_display_name } from "../../_lib";

export async function GET(request: Request) {
  const schema_version = "hr.attendance.log.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const url = new URL(request.url);
  const employee_id = url.searchParams.get("employee_id");
  const department_id = url.searchParams.get("department_id");
  const date_from = url.searchParams.get("date_from");
  const date_to = url.searchParams.get("date_to");
  const status_code = url.searchParams.get("status_code");
  const { page, page_size, from, to } = parse_pagination(request);

  let employee_ids: string[] | null = null;
  if (department_id) {
    const { data: employees_by_department } = await apply_scope(
      ctx.supabase.from("employees").select("id"),
      scope
    ).eq("department_id", department_id);
    employee_ids = (employees_by_department ?? []).map((e) => e.id);
    if (employee_ids.length === 0) {
      return ok(schema_version, { items: [], pagination: { page, page_size, total: 0 } });
    }
  }

  let query = apply_scope(
    ctx.supabase.from("attendance_logs").select("*", { count: "exact" }),
    scope
  );

  if (employee_id) query = query.eq("employee_id", employee_id);
  if (employee_ids) query = query.in("employee_id", employee_ids);
  if (date_from) query = query.gte("attendance_date", date_from);
  if (date_to) query = query.lte("attendance_date", date_to);
  if (status_code) query = query.eq("status_code", status_code);

  const { data: logs, count, error } = await query
    .order("checked_at", { ascending: false })
    .range(from, to);
  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch attendance logs", 500);

  const target_employee_ids = Array.from(new Set((logs ?? []).map((log) => log.employee_id)));
  const target_branch_ids = Array.from(new Set((logs ?? []).map((log) => log.branch_id).filter(Boolean)));
  const [{ data: employees }, { data: branches }, { data: boundaries }] = await Promise.all([
    target_employee_ids.length > 0
      ? apply_scope(
          ctx.supabase.from("employees").select("id,employee_code,display_name,preferred_name,legal_name"),
          scope
        ).in("id", target_employee_ids)
      : Promise.resolve({ data: [] }),
    target_branch_ids.length > 0
      ? apply_scope(ctx.supabase.from("branches").select("id,name"), scope).in("id", target_branch_ids)
      : Promise.resolve({ data: [] }),
    apply_scope(
      ctx.supabase.from("attendance_boundary_settings").select("branch_id,checkin_radius_m,is_attendance_enabled"),
      scope
    )
  ]);
  const employee_map = new Map((employees ?? []).map((e) => [e.id, e]));
  const branch_map = new Map((branches ?? []).map((b) => [b.id, b]));
  const company_default_boundary = (boundaries ?? []).find((b) => !b.branch_id) ?? null;
  const branch_boundary_map = new Map(
    (boundaries ?? [])
      .filter((b) => !!b.branch_id)
      .map((b) => [b.branch_id as string, { checkin_radius_m: b.checkin_radius_m, is_attendance_enabled: b.is_attendance_enabled }])
  );

  const items = (logs ?? []).map((log) => {
    const employee = employee_map.get(log.employee_id);
    const branch = log.branch_id ? branch_map.get(log.branch_id) ?? null : null;
    const branch_boundary = log.branch_id ? branch_boundary_map.get(log.branch_id) ?? null : null;
    const resolved_from = branch_boundary ? "branch_override" : company_default_boundary ? "company_default" : "none";
    return {
      id: log.id,
      employee: employee
        ? {
            id: employee.id,
            employee_code: employee.employee_code,
            display_name: get_display_name(employee)
          }
        : {
            id: log.employee_id,
            employee_code: null,
            display_name: null
          },
      attendance_date: log.attendance_date,
      check_type: log.check_type,
      checked_at: log.checked_at,
      branch_id: log.branch_id ?? null,
      branch_name: branch?.name ?? null,
      location_name: branch?.name ?? null,
      resolved_from,
      resolved_checkin_radius_m: branch_boundary?.checkin_radius_m ?? company_default_boundary?.checkin_radius_m ?? null,
      resolved_is_attendance_enabled:
        branch_boundary?.is_attendance_enabled ?? company_default_boundary?.is_attendance_enabled ?? true,
      source_type: log.source_type,
      status_code: log.status_code,
      is_valid: log.is_valid,
      is_adjusted: log.is_adjusted,
      note: log.note
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

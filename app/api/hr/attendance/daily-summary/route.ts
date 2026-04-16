import { ok, fail, get_access_context, resolve_scope, can_read, apply_scope, get_display_name } from "../../_lib";

type SummaryItem = {
  employee_id: string;
  attendance_date: string;
  branch_id: string | null;
  branch_ids: string[];
  first_check_in_at: string | null;
  last_check_out_at: string | null;
  day_status: string;
  work_minutes: number;
  has_adjustment: boolean;
  log_ids: string[];
};

const DAY_STATUS_PRIORITY = ["invalid", "late", "early_leave", "manual_adjusted", "normal", "missing"];

export async function GET(request: Request) {
  const schema_version = "hr.attendance.daily_summary.v1";
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

  let employee_filter_ids: string[] | null = null;
  if (department_id) {
    const { data: employees_in_department } = await apply_scope(
      ctx.supabase.from("employees").select("id"),
      scope
    ).eq("department_id", department_id);
    employee_filter_ids = (employees_in_department ?? []).map((e) => e.id);
    if (employee_filter_ids.length === 0) {
      return ok(schema_version, { items: [] });
    }
  }

  let query = apply_scope(ctx.supabase.from("attendance_logs").select("*"), scope);
  if (employee_id) query = query.eq("employee_id", employee_id);
  if (employee_filter_ids) query = query.in("employee_id", employee_filter_ids);
  if (date_from) query = query.gte("attendance_date", date_from);
  if (date_to) query = query.lte("attendance_date", date_to);

  const { data: logs, error } = await query.order("attendance_date", { ascending: true }).order("checked_at", { ascending: true });
  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch attendance logs", 500);

  const summary_map = new Map<string, SummaryItem>();
  for (const log of logs ?? []) {
    const key = `${log.employee_id}::${log.attendance_date}`;
    const current = summary_map.get(key) ?? {
      employee_id: log.employee_id,
      attendance_date: log.attendance_date,
      branch_id: null,
      branch_ids: [],
      first_check_in_at: null,
      last_check_out_at: null,
      day_status: "normal",
      work_minutes: 0,
      has_adjustment: false,
      log_ids: []
    };

    current.log_ids.push(log.id);
    if (log.branch_id && !current.branch_ids.includes(log.branch_id)) current.branch_ids.push(log.branch_id);
    current.branch_id = current.branch_ids.length === 1 ? current.branch_ids[0] : null;
    if (log.check_type === "check_in") {
      if (!current.first_check_in_at || new Date(log.checked_at) < new Date(current.first_check_in_at)) {
        current.first_check_in_at = log.checked_at;
      }
    }
    if (log.check_type === "check_out") {
      if (!current.last_check_out_at || new Date(log.checked_at) > new Date(current.last_check_out_at)) {
        current.last_check_out_at = log.checked_at;
      }
    }

    const current_priority = DAY_STATUS_PRIORITY.indexOf(current.day_status);
    const next_priority = DAY_STATUS_PRIORITY.indexOf(log.status_code);
    if (next_priority !== -1 && (current_priority === -1 || next_priority < current_priority)) {
      current.day_status = log.status_code;
    }

    summary_map.set(key, current);
  }

  const summaries = Array.from(summary_map.values());
  const all_log_ids = summaries.flatMap((s) => s.log_ids);

  const { data: adjustments } =
    all_log_ids.length > 0
      ? await apply_scope(ctx.supabase.from("attendance_adjustments").select("attendance_log_id"), scope).in("attendance_log_id", all_log_ids)
      : { data: [] };
  const adjusted_log_ids = new Set((adjustments ?? []).map((a) => a.attendance_log_id));

  for (const summary of summaries) {
    if (summary.first_check_in_at && summary.last_check_out_at) {
      const minutes = Math.floor(
        (new Date(summary.last_check_out_at).getTime() - new Date(summary.first_check_in_at).getTime()) / 60000
      );
      summary.work_minutes = Math.max(0, minutes);
    }
    summary.has_adjustment = summary.log_ids.some((id) => adjusted_log_ids.has(id));
  }

  const employee_ids = Array.from(new Set(summaries.map((s) => s.employee_id)));
  const branch_ids = Array.from(new Set(summaries.map((s) => s.branch_id).filter(Boolean)));
  const [{ data: employees }, { data: branches }, { data: boundaries }] = await Promise.all([
    employee_ids.length > 0
      ? apply_scope(
          ctx.supabase.from("employees").select("id,employee_code,display_name,preferred_name,legal_name"),
          scope
        ).in("id", employee_ids)
      : Promise.resolve({ data: [] }),
    branch_ids.length > 0
      ? apply_scope(ctx.supabase.from("branches").select("id,name"), scope).in("id", branch_ids)
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

  return ok(schema_version, {
    items: summaries.map((summary) => {
      const employee = employee_map.get(summary.employee_id);
      const branch = summary.branch_id ? branch_map.get(summary.branch_id) ?? null : null;
      const branch_boundary = summary.branch_id ? branch_boundary_map.get(summary.branch_id) ?? null : null;
      const resolved_from = summary.branch_ids.length > 1
        ? "mixed"
        : branch_boundary
          ? "branch_override"
          : company_default_boundary
            ? "company_default"
            : "none";
      return {
        employee: employee
          ? {
              id: employee.id,
              employee_code: employee.employee_code,
              display_name: get_display_name(employee)
            }
          : {
            id: summary.employee_id,
            employee_code: null,
            display_name: null
          },
        attendance_date: summary.attendance_date,
        branch_id: summary.branch_id,
        branch_name: branch?.name ?? null,
        location_name: branch?.name ?? null,
        resolved_from,
        resolved_checkin_radius_m: branch_boundary?.checkin_radius_m ?? company_default_boundary?.checkin_radius_m ?? null,
        resolved_is_attendance_enabled:
          branch_boundary?.is_attendance_enabled ?? company_default_boundary?.is_attendance_enabled ?? true,
        first_check_in_at: summary.first_check_in_at,
        last_check_out_at: summary.last_check_out_at,
        day_status: summary.day_status,
        work_minutes: summary.work_minutes,
        has_adjustment: summary.has_adjustment
      };
    })
  });
}

import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_read,
  apply_scope,
  parse_pagination,
  get_display_name
} from "../../../hr/_lib";
import { get_service_supabase } from "../_lib";

function parse_positive_int(value: string | null, fallback: number, max = 100) {
  if (!value) return fallback;
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(1, Math.floor(n)));
}

function map_event_result_status(decision_code: string | null, attendance_log_id: string | null) {
  if (decision_code === "ACCEPTED" || attendance_log_id) return "success";
  if (!decision_code) return "unknown";
  if (decision_code.includes("DUPLICATE")) return "duplicate";
  return "failed";
}

export async function GET(request: Request) {
  const schema_version = "integration.line.audit.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const url = new URL(request.url);
  const line_user_id = url.searchParams.get("line_user_id");
  const binding_limit = parse_positive_int(url.searchParams.get("binding_limit"), 20, 50);
  const checkin_limit = parse_positive_int(url.searchParams.get("checkin_limit"), 20, 50);
  const { page, page_size, from, to } = parse_pagination(request);

  let events_query = apply_scope(
    service
      .from("line_webhook_event_logs")
      .select(
        "id,event_id,event_type,line_user_id,source_ref,attendance_log_id,decision_code,decision_message,branch_id,created_at",
        { count: "exact" }
      ),
    scope
  );
  if (line_user_id) events_query = events_query.eq("line_user_id", line_user_id);

  let bindings_query = apply_scope(
    service
      .from("line_bindings")
      .select("id,line_user_id,employee_id,user_id,bind_status,bound_at,revoked_at,last_seen_at,updated_at,created_at,branch_id"),
    scope
  );
  if (line_user_id) bindings_query = bindings_query.eq("line_user_id", line_user_id);

  const [events_result, bindings_result, checkins_result] = await Promise.all([
    events_query.order("created_at", { ascending: false }).range(from, to),
    bindings_query.order("updated_at", { ascending: false }).limit(binding_limit),
    apply_scope(
      service
        .from("attendance_logs")
        .select("id,employee_id,branch_id,attendance_date,check_type,checked_at,source_type,source_ref,status_code,is_valid,is_adjusted,created_at"),
      scope
    )
      .eq("source_type", "line")
      .order("checked_at", { ascending: false })
      .limit(checkin_limit)
  ]);

  if (events_result.error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch line webhook events", 500);
  }
  if (bindings_result.error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch line bindings", 500);
  }
  if (checkins_result.error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch line check-in logs", 500);
  }

  const events = events_result.data ?? [];
  const bindings = bindings_result.data ?? [];
  const checkins = checkins_result.data ?? [];

  const attendance_log_ids = Array.from(new Set(events.map((e) => e.attendance_log_id).filter(Boolean)));
  const event_line_user_ids = Array.from(new Set(events.map((e) => e.line_user_id).filter(Boolean)));
  const binding_line_user_ids = Array.from(new Set(bindings.map((b) => b.line_user_id).filter(Boolean)));
  const all_line_user_ids = Array.from(new Set([...event_line_user_ids, ...binding_line_user_ids]));

  const [event_attendance_result, latest_bindings_result] = await Promise.all([
    attendance_log_ids.length > 0
      ? apply_scope(
          service
            .from("attendance_logs")
            .select("id,employee_id,branch_id,attendance_date,check_type,checked_at,source_type,source_ref,status_code,is_valid,is_adjusted,created_at"),
          scope
        ).in("id", attendance_log_ids)
      : Promise.resolve({ data: [], error: null }),
    all_line_user_ids.length > 0
      ? apply_scope(
          service
            .from("line_bindings")
            .select("line_user_id,employee_id,user_id,bind_status,bound_at,revoked_at,last_seen_at,updated_at"),
          scope
        )
          .in("line_user_id", all_line_user_ids)
          .order("updated_at", { ascending: false })
      : Promise.resolve({ data: [], error: null })
  ]);

  if (event_attendance_result.error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch event attendance logs", 500);
  }
  if (latest_bindings_result.error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch latest line binding map", 500);
  }

  const event_attendance_map = new Map((event_attendance_result.data ?? []).map((row) => [row.id, row]));

  const latest_binding_map = new Map<string, any>();
  for (const row of latest_bindings_result.data ?? []) {
    if (row.line_user_id && !latest_binding_map.has(row.line_user_id)) {
      latest_binding_map.set(row.line_user_id, row);
    }
  }

  const employee_ids = Array.from(
    new Set([
      ...bindings.map((b) => b.employee_id).filter(Boolean),
      ...checkins.map((c) => c.employee_id).filter(Boolean),
      ...(event_attendance_result.data ?? []).map((l) => l.employee_id).filter(Boolean),
      ...Array.from(latest_binding_map.values()).map((m: any) => m.employee_id).filter(Boolean)
    ])
  );
  const user_ids = Array.from(
    new Set([
      ...bindings.map((b) => b.user_id).filter(Boolean),
      ...Array.from(latest_binding_map.values()).map((m: any) => m.user_id).filter(Boolean)
    ])
  );
  const branch_ids = Array.from(
    new Set([
      ...events.map((e) => e.branch_id).filter(Boolean),
      ...bindings.map((b) => b.branch_id).filter(Boolean),
      ...checkins.map((c) => c.branch_id).filter(Boolean),
      ...(event_attendance_result.data ?? []).map((l) => l.branch_id).filter(Boolean)
    ])
  );

  const [employees_result, users_result, branches_result] = await Promise.all([
    employee_ids.length > 0
      ? apply_scope(
          service
            .from("employees")
            .select("id,employee_code,display_name,preferred_name,legal_name,full_name_local,full_name_latin"),
          scope
        ).in("id", employee_ids)
      : Promise.resolve({ data: [], error: null }),
    user_ids.length > 0
      ? service.from("users").select("id,email,display_name,locale_preference").in("id", user_ids)
      : Promise.resolve({ data: [], error: null }),
    branch_ids.length > 0
      ? apply_scope(service.from("branches").select("id,name"), scope).in("id", branch_ids)
      : Promise.resolve({ data: [], error: null })
  ]);

  if (employees_result.error || users_result.error || branches_result.error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve audit references", 500);
  }

  const employee_map = new Map((employees_result.data ?? []).map((e) => [e.id, e]));
  const user_map = new Map((users_result.data ?? []).map((u) => [u.id, u]));
  const branch_map = new Map((branches_result.data ?? []).map((b) => [b.id, b]));

  const map_employee = (employee_id_value: string | null) => {
    if (!employee_id_value) return null;
    const employee = employee_map.get(employee_id_value);
    if (!employee) return { id: employee_id_value, employee_code: null, display_name: null, full_name_local: null, full_name_latin: null };
    return {
      id: employee.id,
      employee_code: employee.employee_code,
      display_name: get_display_name(employee),
      full_name_local: employee.full_name_local ?? null,
      full_name_latin: employee.full_name_latin ?? null
    };
  };

  const map_user = (user_id_value: string | null) => {
    if (!user_id_value) return null;
    const user = user_map.get(user_id_value);
    if (!user) return { id: user_id_value, email: null, display_name: null, locale_preference: null };
    return {
      id: user.id,
      email: user.email ?? null,
      display_name: user.display_name ?? null,
      locale_preference: user.locale_preference ?? null
    };
  };

  const event_items = events.map((event) => {
    const linked_attendance = event.attendance_log_id ? event_attendance_map.get(event.attendance_log_id) ?? null : null;
    const linked_binding = event.line_user_id ? latest_binding_map.get(event.line_user_id) ?? null : null;
    const resolved_employee_id = linked_binding?.employee_id ?? linked_attendance?.employee_id ?? null;
    const result_status = map_event_result_status(event.decision_code ?? null, event.attendance_log_id ?? null);
    return {
      id: event.id,
      event_id: event.event_id ?? null,
      event_type: event.event_type,
      line_user_id: event.line_user_id ?? null,
      created_at: event.created_at,
      result_status,
      failure_reason: result_status === "failed" ? event.decision_code ?? "UNKNOWN_FAILURE" : null,
      decision_code: event.decision_code ?? null,
      decision_message: event.decision_message ?? null,
      employee: map_employee(resolved_employee_id),
      user: map_user(linked_binding?.user_id ?? null),
      binding: linked_binding
        ? {
            bind_status: linked_binding.bind_status ?? null,
            bound_at: linked_binding.bound_at ?? null,
            revoked_at: linked_binding.revoked_at ?? null,
            last_seen_at: linked_binding.last_seen_at ?? null,
            updated_at: linked_binding.updated_at ?? null
          }
        : null,
      check_in_result: linked_attendance
        ? {
            attendance_log_id: linked_attendance.id,
            attendance_date: linked_attendance.attendance_date,
            check_type: linked_attendance.check_type,
            checked_at: linked_attendance.checked_at,
            source_type: linked_attendance.source_type,
            status_code: linked_attendance.status_code,
            is_valid: linked_attendance.is_valid,
            branch_id: linked_attendance.branch_id ?? null,
            branch_name: linked_attendance.branch_id ? branch_map.get(linked_attendance.branch_id)?.name ?? null : null
          }
        : null
    };
  });

  const binding_items = bindings.map((binding) => ({
    id: binding.id,
    line_user_id: binding.line_user_id,
    bind_status: binding.bind_status,
    bound_at: binding.bound_at,
    revoked_at: binding.revoked_at ?? null,
    last_seen_at: binding.last_seen_at ?? null,
    updated_at: binding.updated_at,
    created_at: binding.created_at,
    branch_id: binding.branch_id ?? null,
    branch_name: binding.branch_id ? branch_map.get(binding.branch_id)?.name ?? null : null,
    employee: map_employee(binding.employee_id ?? null),
    user: map_user(binding.user_id ?? null)
  }));

  const checkin_items = checkins.map((log) => ({
    id: log.id,
    attendance_date: log.attendance_date,
    check_type: log.check_type,
    checked_at: log.checked_at,
    source_type: log.source_type,
    source_ref: log.source_ref ?? null,
    status_code: log.status_code,
    is_valid: log.is_valid,
    is_adjusted: log.is_adjusted,
    created_at: log.created_at,
    branch_id: log.branch_id ?? null,
    branch_name: log.branch_id ? branch_map.get(log.branch_id)?.name ?? null : null,
    employee: map_employee(log.employee_id ?? null)
  }));

  return ok(schema_version, {
    events: event_items,
    bindings: binding_items,
    checkins: checkin_items,
    pagination: {
      page,
      page_size,
      total: events_result.count ?? 0
    },
    summary: {
      events_returned: event_items.length,
      bindings_returned: binding_items.length,
      checkins_returned: checkin_items.length,
      line_checkins_source_type: "line"
    }
  });
}

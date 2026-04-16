import {
  ok,
  fail,
  get_access_context,
  reject_preview_override_write,
  can_read,
  apply_scope,
  local_date_in_timezone,
  local_minutes_in_timezone,
  parse_hhmm_to_minutes
} from "../../_lib";

const CHECK_TYPES = new Set(["check_in", "check_out"]);
const SOURCE_TYPES = new Set(["web", "mobile", "kiosk", "line_liff", "line", "manual", "import", "manual_upload", "external_api"]);

function compute_status_code(params: {
  check_type: string;
  checked_at: string;
  timezone: string;
  standard_check_in_time: string | null;
  standard_check_out_time: string | null;
  late_grace_minutes: number;
  early_leave_grace_minutes: number;
}) {
  const local_minutes = local_minutes_in_timezone(params.checked_at, params.timezone);
  if (params.check_type === "check_in") {
    const standard_minutes = parse_hhmm_to_minutes(params.standard_check_in_time);
    if (standard_minutes === null) return "normal";
    return local_minutes > standard_minutes + params.late_grace_minutes ? "late" : "normal";
  }

  const standard_minutes = parse_hhmm_to_minutes(params.standard_check_out_time);
  if (standard_minutes === null) return "normal";
  return local_minutes < standard_minutes - params.early_leave_grace_minutes ? "early_leave" : "normal";
}

export async function POST(request: Request) {
  const schema_version = "hr.attendance.check.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const body = (await request.json()) as Record<string, unknown>;
  const employee_id = String(body.employee_id ?? "");
  const check_type = String(body.check_type ?? "");
  const checked_at = String(body.checked_at ?? "");
  const source_type = String(body.source_type ?? "");
  if (!employee_id || !check_type || !checked_at || !source_type) {
    return fail(schema_version, "INVALID_REQUEST", "employee_id, check_type, checked_at, source_type are required", 400);
  }
  if (!CHECK_TYPES.has(check_type)) {
    return fail(schema_version, "INVALID_CHECK_TYPE", "Invalid check_type", 400);
  }
  if (!SOURCE_TYPES.has(source_type)) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid source_type", 400);
  }

  const { data: employee, error: employee_error } = await ctx.supabase
    .from("employees")
    .select("id,org_id,company_id,branch_id,environment_type,is_demo")
    .eq("id", employee_id)
    .maybeSingle();
  if (employee_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  const readable = can_read(ctx, {
    org_id: employee.org_id,
    company_id: employee.company_id,
    branch_id: employee.branch_id,
    environment_type: employee.environment_type,
    is_demo: employee.is_demo
  });
  if (!readable) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);

  const { data: profile } = await apply_scope(
    ctx.supabase
      .from("employee_attendance_profiles")
      .select("attendance_policy_id,effective_from,effective_to,is_current"),
    {
      org_id: employee.org_id,
      company_id: employee.company_id,
      branch_id: employee.branch_id,
      environment_type: employee.environment_type,
      is_demo: employee.is_demo
    }
  )
    .eq("employee_id", employee.id)
    .eq("is_current", true)
    .order("effective_from", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!profile) {
    return fail(schema_version, "ATTENDANCE_POLICY_NOT_FOUND", "Attendance policy is not configured for employee", 422);
  }

  const { data: policy } = await apply_scope(
    ctx.supabase
      .from("attendance_policies")
      .select("id,policy_name,timezone,standard_check_in_time,standard_check_out_time,late_grace_minutes,early_leave_grace_minutes"),
    {
      org_id: employee.org_id,
      company_id: employee.company_id,
      branch_id: employee.branch_id,
      environment_type: employee.environment_type,
      is_demo: employee.is_demo
    }
  )
    .eq("id", profile.attendance_policy_id)
    .maybeSingle();

  if (!policy) {
    return fail(schema_version, "ATTENDANCE_POLICY_NOT_FOUND", "Attendance policy is not found", 422);
  }

  const attendance_date = local_date_in_timezone(checked_at, policy.timezone);
  const status_code = compute_status_code({
    check_type,
    checked_at,
    timezone: policy.timezone,
    standard_check_in_time: policy.standard_check_in_time,
    standard_check_out_time: policy.standard_check_out_time,
    late_grace_minutes: policy.late_grace_minutes,
    early_leave_grace_minutes: policy.early_leave_grace_minutes
  });

  const { data: created, error: create_error } = await ctx.supabase
    .from("attendance_logs")
    .insert({
      org_id: employee.org_id,
      company_id: employee.company_id,
      branch_id: employee.branch_id,
      environment_type: employee.environment_type,
      is_demo: employee.is_demo,
      employee_id: employee.id,
      attendance_date,
      check_type,
      checked_at,
      source_type,
      source_ref: body.source_ref ?? null,
      gps_lat: body.gps_lat ?? null,
      gps_lng: body.gps_lng ?? null,
      geo_distance_m: body.geo_distance_m ?? null,
      is_within_geo_range: body.is_within_geo_range ?? null,
      status_code,
      is_valid: true,
      is_adjusted: false,
      note: body.note ?? null,
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id")
    .maybeSingle();

  if (create_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to create attendance log", 500);

  return ok(schema_version, {
    attendance_log_id: created?.id ?? null,
    attendance_date,
    status_code,
    is_within_geo_range: body.is_within_geo_range ?? null,
    policy_snapshot: {
      policy_id: policy.id,
      policy_name: policy.policy_name,
      timezone: policy.timezone,
      standard_check_in_time: policy.standard_check_in_time,
      late_grace_minutes: policy.late_grace_minutes
    }
  }, 201);
}

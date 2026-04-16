import { ok, fail, get_access_context, can_write, apply_scope, reject_preview_override_write } from "../../_lib";

const ADJUSTMENT_TYPES = new Set(["time_correction", "invalidate", "note_update", "status_override"]);

export async function POST(request: Request) {
  const schema_version = "hr.attendance.adjustment.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const body = (await request.json()) as Record<string, unknown>;
  const attendance_log_id = String(body.attendance_log_id ?? "");
  const adjustment_type = String(body.adjustment_type ?? "");
  const reason = String(body.reason ?? "").trim();
  if (!attendance_log_id || !adjustment_type || !reason) {
    return fail(schema_version, "INVALID_REQUEST", "attendance_log_id, adjustment_type and reason are required", 400);
  }
  if (!ADJUSTMENT_TYPES.has(adjustment_type)) {
    return fail(schema_version, "ATTENDANCE_ADJUSTMENT_NOT_ALLOWED", "Invalid adjustment_type", 400);
  }

  const { data: attendance_log, error: log_error } = await ctx.supabase
    .from("attendance_logs")
    .select("*")
    .eq("id", attendance_log_id)
    .maybeSingle();
  if (log_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch attendance log", 500);
  if (!attendance_log) return fail(schema_version, "ATTENDANCE_LOG_NOT_FOUND", "Attendance log not found", 404);

  const writable = can_write(ctx, {
    org_id: attendance_log.org_id,
    company_id: attendance_log.company_id,
    branch_id: attendance_log.branch_id,
    environment_type: attendance_log.environment_type,
    is_demo: attendance_log.is_demo
  });
  if (!writable) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);

  if (adjustment_type === "invalidate" && attendance_log.is_valid === false) {
    return fail(schema_version, "ATTENDANCE_ALREADY_INVALIDATED", "Attendance log is already invalidated", 409);
  }

  const { data: created, error: create_error } = await ctx.supabase
    .from("attendance_adjustments")
    .insert({
      org_id: attendance_log.org_id,
      company_id: attendance_log.company_id,
      branch_id: attendance_log.branch_id,
      environment_type: attendance_log.environment_type,
      is_demo: attendance_log.is_demo,
      attendance_log_id: attendance_log.id,
      employee_id: attendance_log.employee_id,
      adjustment_type,
      requested_value: body.requested_value ?? null,
      original_value: attendance_log,
      reason,
      approval_status: "pending",
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id,approval_status")
    .maybeSingle();

  if (create_error) {
    return fail(schema_version, "ATTENDANCE_ADJUSTMENT_NOT_ALLOWED", "Failed to create attendance adjustment", 500);
  }

  return ok(schema_version, {
    adjustment_id: created?.id ?? null,
    approval_status: created?.approval_status ?? "pending"
  }, 201);
}

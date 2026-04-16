import {
  fail,
  get_access_context,
  ok,
  resolve_scope,
  can_read,
  can_write,
  apply_scope,
  parse_pagination,
  reject_preview_override_write
} from "../_lib";

const STAGING_VALUES = [process.env.APP_ENV, process.env.NEXT_PUBLIC_APP_ENV, process.env.DEPLOY_TARGET]
  .filter(Boolean)
  .map((v) => String(v).toLowerCase());

export function ensure_staging_only(schema_version: string) {
  const isStaging = STAGING_VALUES.some((v) => v === "staging" || v.includes("staging"));
  if (isStaging) return null;
  return fail(schema_version, "STAGING_ONLY", "This endpoint is available in staging only", 403);
}

export async function get_leave_read_context(request: Request) {
  const schema_version = "hr.leave.security.v1";
  const stagingError = ensure_staging_only(schema_version);
  if (stagingError) return { response: stagingError, ctx: null, scope: null };

  const ctx = await get_access_context(request);
  if (!ctx) return { response: fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401), ctx: null, scope: null };

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return {
      response: fail(schema_version, "SCOPE_FORBIDDEN", "Leave scope is not readable", 403),
      ctx,
      scope: null
    };
  }

  return { response: null, ctx, scope };
}

export async function get_leave_write_context(request: Request) {
  const schema_version = "hr.leave.security.v1";
  const stagingError = ensure_staging_only(schema_version);
  if (stagingError) return { response: stagingError, ctx: null, scope: null };

  const ctx = await get_access_context(request);
  if (!ctx) return { response: fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401), ctx: null, scope: null };

  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return { response: previewError, ctx, scope: null };

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return {
      response: fail(schema_version, "SCOPE_FORBIDDEN", "Leave scope is not writable", 403),
      ctx,
      scope: null
    };
  }

  return { response: null, ctx, scope };
}

export async function get_scoped_leave_request(ctx: any, scope: any, leave_request_id: string) {
  const { data, error } = await apply_scope(
    ctx.supabase
      .from("leave_requests")
      .select("id,org_id,company_id,employee_id,environment_type,is_demo,approval_status")
      .eq("id", leave_request_id),
    scope
  ).maybeSingle();

  return { data, error };
}

export function map_leave_rpc_error(schema_version: string, error: any, fallbackMessage: string) {
  const message = String(error?.message ?? fallbackMessage);

  if (message.includes("LEAVE_REQUEST_NOT_FOUND")) {
    return fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404);
  }
  if (message.includes("EMPLOYEE_NOT_FOUND")) {
    return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee is not found", 400);
  }
  if (message.includes("EMPLOYEE_SCOPE_MISMATCH")) {
    return fail(schema_version, "EMPLOYEE_SCOPE_MISMATCH", "Employee does not belong to the selected scope", 400);
  }
  if (message.includes("INVALID_JSON_BODY")) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid JSON body", 400);
  }
  if (message.includes("LEAVE_TYPE_REQUIRED")) {
    return fail(schema_version, "LEAVE_TYPE_REQUIRED", "leave_type is required", 400);
  }
  if (message.includes("LEAVE_DATE_REQUIRED")) {
    return fail(schema_version, "LEAVE_DATE_REQUIRED", "start_date and end_date are required", 400);
  }
  if (message.includes("LEAVE_REASON_REQUIRED")) {
    return fail(schema_version, "LEAVE_REASON_REQUIRED", "reason is required", 400);
  }
  if (message.includes("INVALID_LEAVE_DATE_RANGE")) {
    return fail(schema_version, "INVALID_LEAVE_DATE_RANGE", "Invalid leave date range", 400);
  }
  if (message.includes("REJECTION_REASON_REQUIRED")) {
    return fail(schema_version, "REJECTION_REASON_REQUIRED", "rejection reason is required", 400);
  }
  if (message.includes("LEAVE_REQUEST_ALREADY_APPROVED")) {
    return fail(schema_version, "LEAVE_REQUEST_ALREADY_APPROVED", "Leave request is already approved", 409);
  }
  if (message.includes("LEAVE_REQUEST_ALREADY_CANCELLED")) {
    return fail(schema_version, "LEAVE_REQUEST_ALREADY_CANCELLED", "Leave request is already cancelled", 409);
  }

  return fail(schema_version, "INTERNAL_ERROR", fallbackMessage, 500, {
    rpc_message: message
  });
}

export function normalize_leave_list_row(row: any) {
  return {
    id: row.leave_request_id,
    employee_id: row.employee_id,
    employee_code: row.employee_code,
    employee_display_name: row.employee_display_name,
    leave_type: row.leave_type,
    start_date: row.start_date,
    end_date: row.end_date,
    start_time: row.start_time,
    end_time: row.end_time,
    duration_hours: row.duration_hours,
    duration_days: row.duration_days,
    reason: row.reason,
    approver_user_id: row.approver_user_id,
    approval_status: row.approval_status,
    approved_at: row.approved_at,
    rejected_at: row.rejected_at,
    rejection_reason: row.rejection_reason,
    affects_payroll: row.affects_payroll,
    created_at: row.created_at,
    updated_at: row.updated_at,
    last_action: row.last_action,
    last_action_at: row.last_action_at
  };
}

export function ok_with_meta(schema_version: string, data: Record<string, unknown>, status = 200) {
  return ok(schema_version, data, status);
}

export function get_pagination_from_request(request: Request) {
  return parse_pagination(request);
}

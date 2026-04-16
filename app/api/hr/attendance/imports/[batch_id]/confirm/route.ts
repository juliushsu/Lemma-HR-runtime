import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_write,
  reject_preview_override_write
} from "../../../../_lib";
import {
  get_service_supabase,
  parse_attendance_date,
  parse_check_type,
  parse_datetime_iso
} from "../../_lib";

type ConfirmCorrection = {
  row_id: string;
  employee_code?: string | null;
  attendance_date?: string | null;
  check_type?: string | null;
  checked_at?: string | null;
  branch_id?: string | null;
  reason?: string | null;
  note?: string | null;
};

type ConfirmRequest = {
  corrections?: ConfirmCorrection[];
  reject_row_ids?: string[];
};

type RowFailure = {
  row_id: string;
  row_index: number;
  error_code: string;
  error_message: string;
};

const BRANCH_NAME_KEYS = ["branch_name", "branch name", "location_name", "location name", "branch", "分店"];

function value_or<T>(override: T | undefined, base: T): T {
  return override === undefined ? base : override;
}

function normalize_key(input: string) {
  return input.trim().toLowerCase().replace(/\s+/g, "_");
}

function get_raw_branch_name(parsed_payload: Record<string, unknown> | null): string | null {
  if (!parsed_payload) return null;
  const normalized = new Map<string, unknown>();
  for (const [key, value] of Object.entries(parsed_payload)) {
    normalized.set(normalize_key(key), value);
  }

  for (const key of BRANCH_NAME_KEYS) {
    const value = normalized.get(normalize_key(key));
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      return String(value).trim();
    }
  }
  return null;
}

function normalize_correction_map(corrections: ConfirmCorrection[] | undefined) {
  const map = new Map<string, ConfirmCorrection>();
  for (const correction of corrections ?? []) {
    if (correction.row_id) map.set(correction.row_id, correction);
  }
  return map;
}

export async function POST(
  request: Request,
  { params }: { params: { batch_id: string } }
) {
  const schema_version = "hr.attendance.import.confirm.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const batch_id = params.batch_id;
  if (!batch_id) return fail(schema_version, "INVALID_REQUEST", "batch_id is required", 400);

  const body = (await request.json().catch(() => ({}))) as ConfirmRequest;
  const correction_map = normalize_correction_map(body.corrections);
  const reject_set = new Set((body.reject_row_ids ?? []).filter(Boolean));

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const { data: batch, error: batch_error } = await service
    .from("attendance_import_batches")
    .select("id,org_id,company_id,branch_id,environment_type,is_demo,status")
    .eq("id", batch_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .maybeSingle();

  if (batch_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch import batch", 500);
  if (!batch) return fail(schema_version, "BATCH_NOT_FOUND", "Import batch not found", 404);
  if (batch.status === "imported") {
    return fail(schema_version, "BATCH_ALREADY_IMPORTED", "Import batch already imported", 409);
  }

  await service
    .from("attendance_import_batches")
    .update({ status: "importing", updated_at: new Date().toISOString(), updated_by: ctx.user_id })
    .eq("id", batch.id);

  const { data: rows, error: rows_error } = await service
    .from("attendance_import_rows")
    .select("id,row_index,employee_code,attendance_date,check_type,checked_at,branch_id,parsed_payload,status,error_code,error_message")
    .eq("batch_id", batch.id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .order("row_index", { ascending: true });

  if (rows_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch import rows", 500);
  if (!rows || rows.length === 0) return fail(schema_version, "EMPTY_BATCH", "Import batch has no rows", 400);

  const employee_codes = Array.from(
    new Set(
      rows
        .map((r) => correction_map.get(r.id)?.employee_code ?? r.employee_code ?? "")
        .map((v) => String(v).trim())
        .filter(Boolean)
    )
  );

  const [{ data: employees, error: employees_error }, { data: branches, error: branches_error }] = await Promise.all([
    employee_codes.length > 0
      ? service
          .from("employees")
          .select("id,employee_code,branch_id")
          .eq("org_id", scope.org_id)
          .eq("company_id", scope.company_id)
          .eq("environment_type", scope.environment_type)
          .in("employee_code", employee_codes)
      : Promise.resolve({ data: [] as any[], error: null }),
    service
      .from("branches")
      .select("id,name")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .eq("environment_type", scope.environment_type)
  ]);

  if (employees_error || branches_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve employee/branch data", 500);
  }

  const employee_map = new Map((employees ?? []).map((e) => [String(e.employee_code), e]));
  const branch_id_set = new Set((branches ?? []).map((b) => String(b.id)));
  const branch_name_map = new Map((branches ?? []).map((b) => [String(b.name).toLowerCase(), String(b.id)]));

  let imported_count = 0;
  let rejected_count = 0;
  let failed_count = 0;
  const failures: RowFailure[] = [];
  const processed_keys = new Set<string>();

  for (const row of rows) {
    if (reject_set.has(row.id)) {
      rejected_count += 1;
      await service
        .from("attendance_import_rows")
        .update({
          status: "rejected",
          review_note: "Rejected by reviewer",
          reviewed_by: ctx.user_id,
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          updated_by: ctx.user_id
        })
        .eq("id", row.id);
      continue;
    }

    const correction = correction_map.get(row.id);
    const employee_code = String(value_or(correction?.employee_code, row.employee_code ?? "")).trim();
    const check_type = parse_check_type(value_or(correction?.check_type, row.check_type ?? null));
    const checked_at_iso = parse_datetime_iso(value_or(correction?.checked_at, row.checked_at ?? null));
    const attendance_date = parse_attendance_date(value_or(correction?.attendance_date, row.attendance_date ?? null), checked_at_iso);
    const employee = employee_code ? employee_map.get(employee_code) ?? null : null;
    const raw_branch_name = get_raw_branch_name((row.parsed_payload ?? null) as Record<string, unknown> | null);

    let branch_id = value_or(correction?.branch_id, row.branch_id ?? null);
    if (!branch_id && raw_branch_name) {
      branch_id = branch_name_map.get(raw_branch_name.toLowerCase()) ?? null;
    } else if (!branch_id) {
      branch_id = employee?.branch_id ?? null;
    }
    if (branch_id) branch_id = String(branch_id);

    let error_code: string | null = null;
    let error_message: string | null = null;

    if (!employee) {
      error_code = "EMPLOYEE_NOT_FOUND";
      error_message = "employee_code not found in scope";
    } else if (!check_type) {
      error_code = "INVALID_CHECK_TYPE";
      error_message = "check_type must be check_in/check_out";
    } else if (!checked_at_iso || !attendance_date) {
      error_code = "INVALID_DATETIME";
      error_message = "checked_at/attendance_date is invalid";
    } else if (!branch_id || !branch_id_set.has(branch_id)) {
      error_code = "BRANCH_UNRESOLVED";
      error_message = "branch cannot be resolved";
    }

    const dedupe_key = `${employee_code}|${check_type ?? ""}|${checked_at_iso ?? ""}`;
    if (!error_code && processed_keys.has(dedupe_key)) {
      error_code = "DUPLICATE_ROW";
      error_message = "duplicate row in confirm import payload";
    }
    processed_keys.add(dedupe_key);

    if (!error_code && employee && check_type && checked_at_iso) {
      const { data: existing_log } = await service
        .from("attendance_logs")
        .select("id")
        .eq("org_id", scope.org_id)
        .eq("company_id", scope.company_id)
        .eq("environment_type", scope.environment_type)
        .eq("employee_id", employee.id)
        .eq("check_type", check_type)
        .eq("checked_at", checked_at_iso)
        .maybeSingle();
      if (existing_log) {
        error_code = "DUPLICATE_ROW";
        error_message = "duplicate with existing attendance log";
      }
    }

    if (error_code || !employee || !check_type || !checked_at_iso || !attendance_date || !branch_id) {
      failed_count += 1;
      failures.push({
        row_id: row.id,
        row_index: row.row_index,
        error_code: error_code ?? "INVALID_ROW",
        error_message: error_message ?? "row failed validation"
      });

      await service
        .from("attendance_import_rows")
        .update({
          status: "error",
          error_code: error_code ?? "INVALID_ROW",
          error_message: error_message ?? "row failed validation",
          corrected_payload: correction ?? null,
          is_corrected: Boolean(correction),
          review_note: correction?.note ?? null,
          reviewed_by: ctx.user_id,
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          updated_by: ctx.user_id
        })
        .eq("id", row.id);
      continue;
    }

    const is_corrected = Boolean(correction);
    const now_iso = new Date().toISOString();
    const { data: created_log, error: create_log_error } = await service
      .from("attendance_logs")
      .insert({
        org_id: scope.org_id,
        company_id: scope.company_id,
        branch_id,
        environment_type: scope.environment_type,
        is_demo: scope.is_demo,
        employee_id: employee.id,
        attendance_date,
        check_type,
        checked_at: checked_at_iso,
        source_type: "manual_upload",
        source_ref: `manual_upload:${batch.id}:${row.row_index}`,
        status_code: is_corrected ? "manual_adjusted" : "normal",
        is_valid: true,
        is_adjusted: is_corrected,
        note: is_corrected
          ? `Manual upload corrected at confirm import (batch ${batch.id})`
          : `Manual upload import (batch ${batch.id})`,
        created_by: ctx.user_id,
        updated_by: ctx.user_id
      })
      .select("id")
      .maybeSingle();

    if (create_log_error || !created_log) {
      failed_count += 1;
      failures.push({
        row_id: row.id,
        row_index: row.row_index,
        error_code: "IMPORT_WRITE_FAILED",
        error_message: "failed to write attendance log"
      });
      await service
        .from("attendance_import_rows")
        .update({
          status: "error",
          error_code: "IMPORT_WRITE_FAILED",
          error_message: "failed to write attendance log",
          corrected_payload: correction ?? null,
          is_corrected: is_corrected,
          updated_at: new Date().toISOString(),
          updated_by: ctx.user_id
        })
        .eq("id", row.id);
      continue;
    }

    if (is_corrected) {
      await service.from("attendance_adjustments").insert({
        org_id: scope.org_id,
        company_id: scope.company_id,
        branch_id,
        environment_type: scope.environment_type,
        is_demo: scope.is_demo,
        attendance_log_id: created_log.id,
        employee_id: employee.id,
        adjustment_type: "time_correction",
        requested_value: {
          employee_code,
          attendance_date,
          check_type,
          checked_at: checked_at_iso,
          branch_id
        },
        original_value: row.parsed_payload ?? {},
        reason: correction?.reason ?? "Manual correction during confirm import",
        approval_status: "approved",
        approved_by: ctx.user_id,
        approved_at: now_iso,
        created_by: ctx.user_id,
        updated_by: ctx.user_id
      });
    }

    imported_count += 1;
    await service
      .from("attendance_import_rows")
      .update({
        status: "imported",
        error_code: null,
        error_message: null,
        corrected_payload: correction ?? null,
        is_corrected: is_corrected,
        review_note: correction?.note ?? null,
        reviewed_by: is_corrected ? ctx.user_id : null,
        reviewed_at: is_corrected ? now_iso : null,
        imported_attendance_log_id: created_log.id,
        updated_at: now_iso,
        updated_by: ctx.user_id
      })
      .eq("id", row.id);
  }

  const final_status =
    imported_count > 0 && failed_count === 0
      ? "imported"
      : imported_count > 0
        ? "partially_imported"
        : "failed";

  await service
    .from("attendance_import_batches")
    .update({
      status: final_status,
      imported_rows: imported_count,
      invalid_rows: failed_count,
      valid_rows: Math.max(0, rows.length - failed_count - rejected_count),
      updated_at: new Date().toISOString(),
      updated_by: ctx.user_id
    })
    .eq("id", batch.id);

  return ok(schema_version, {
    batch_id: batch.id,
    status: final_status,
    summary: {
      total_rows: rows.length,
      imported_rows: imported_count,
      failed_rows: failed_count,
      rejected_rows: rejected_count
    },
    failures
  });
}

import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_write,
  reject_preview_override_write
} from "../../../_lib";
import {
  detect_file_type,
  get_service_supabase,
  parse_upload_file,
  parse_check_type,
  parse_datetime_iso,
  parse_attendance_date
} from "../_lib";
import { featureNotEnabledResponse, resolveFeatureAccess } from "../../../../../lib/featureGating";

type RowErrorCode =
  | "EMPLOYEE_NOT_FOUND"
  | "INVALID_DATETIME"
  | "DUPLICATE_ROW"
  | "BRANCH_UNRESOLVED"
  | "INVALID_CHECK_TYPE";

type StagedRow = {
  row_index: number;
  employee_code: string | null;
  attendance_date: string | null;
  check_type: string | null;
  checked_at: string | null;
  branch_id: string | null;
  parsed_payload: Record<string, unknown>;
  status: "valid" | "error";
  error_code: RowErrorCode | null;
  error_message: string | null;
  is_duplicate: boolean;
};

function chunk<T>(items: T[], size: number) {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

export async function POST(request: Request) {
  const schema_version = "hr.attendance.import.upload_preview.v1";
  const feature_key = "attendance.manual_upload.basic";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const feature_access = await resolveFeatureAccess({
    org_id: scope.org_id,
    feature_key
  });
  if (!feature_access.enabled) {
    return featureNotEnabledResponse(feature_key, 403);
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const form = await request.formData();
  const file = form.get("file");
  if (!(file instanceof File)) {
    return fail(schema_version, "INVALID_REQUEST", "file is required (CSV/XLSX)", 400);
  }

  const file_type = detect_file_type(file.name);
  if (!file_type) {
    return fail(schema_version, "UNSUPPORTED_FILE_TYPE", "Only CSV and XLSX are supported", 400);
  }

  const file_bytes = Buffer.from(await file.arrayBuffer());
  const parsed_rows = parse_upload_file(file_bytes);
  if (parsed_rows.length === 0) {
    return fail(schema_version, "EMPTY_FILE", "No rows found in uploaded file", 400);
  }

  const employee_codes = Array.from(
    new Set(parsed_rows.map((r) => (r.employee_code ?? "").trim()).filter(Boolean))
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
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve employee/branch mapping", 500);
  }

  const employee_map = new Map((employees ?? []).map((e) => [String(e.employee_code), e]));
  const branch_id_map = new Map((branches ?? []).map((b) => [String(b.id), String(b.id)]));
  const branch_name_map = new Map((branches ?? []).map((b) => [String(b.name).toLowerCase(), String(b.id)]));

  const duplicate_seen = new Set<string>();
  const staged_rows: StagedRow[] = [];

  for (const row of parsed_rows) {
    const employee = row.employee_code ? employee_map.get(row.employee_code) ?? null : null;
    const normalized_check_type = parse_check_type(row.check_type);
    const normalized_checked_at = parse_datetime_iso(row.checked_at);
    const normalized_attendance_date = parse_attendance_date(row.attendance_date, normalized_checked_at);

    let branch_id: string | null = null;
    if (row.branch_id) {
      branch_id = branch_id_map.get(row.branch_id) ?? null;
    } else if (row.branch_name) {
      branch_id = branch_name_map.get(row.branch_name.toLowerCase()) ?? null;
    } else {
      branch_id = employee?.branch_id ?? null;
    }

    let error_code: RowErrorCode | null = null;
    let error_message: string | null = null;

    if (!employee) {
      error_code = "EMPLOYEE_NOT_FOUND";
      error_message = "employee_code not found in scope";
    } else if (!normalized_check_type) {
      error_code = "INVALID_CHECK_TYPE";
      error_message = "check_type must be check_in/check_out";
    } else if (!normalized_checked_at || !normalized_attendance_date) {
      error_code = "INVALID_DATETIME";
      error_message = "checked_at/attendance_date is invalid";
    } else if (!branch_id) {
      error_code = "BRANCH_UNRESOLVED";
      error_message = "branch cannot be resolved";
    }

    const dedupe_key = `${row.employee_code ?? ""}|${normalized_check_type ?? ""}|${normalized_checked_at ?? ""}`;
    const is_duplicate = duplicate_seen.has(dedupe_key);
    if (!error_code && is_duplicate) {
      error_code = "DUPLICATE_ROW";
      error_message = "duplicate row in upload file";
    }
    duplicate_seen.add(dedupe_key);

    staged_rows.push({
      row_index: row.row_index,
      employee_code: row.employee_code,
      attendance_date: normalized_attendance_date,
      check_type: normalized_check_type,
      checked_at: normalized_checked_at,
      branch_id,
      parsed_payload: row.raw,
      status: error_code ? "error" : "valid",
      error_code,
      error_message,
      is_duplicate
    });
  }

  const total_rows = staged_rows.length;
  const valid_rows = staged_rows.filter((r) => r.status === "valid").length;
  const invalid_rows = total_rows - valid_rows;
  const duplicate_rows = staged_rows.filter((r) => r.error_code === "DUPLICATE_ROW").length;

  const { data: batch, error: batch_error } = await service
    .from("attendance_import_batches")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: scope.branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      source_type: "manual_upload",
      file_name: file.name,
      file_type,
      status: "preview_ready",
      total_rows,
      valid_rows,
      invalid_rows,
      duplicate_rows,
      imported_rows: 0,
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id,file_name,file_type,status,total_rows,valid_rows,invalid_rows,duplicate_rows,imported_rows,created_at")
    .maybeSingle();

  if (batch_error || !batch) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create import batch", 500);
  }

  const rows_to_insert = staged_rows.map((row) => ({
    batch_id: batch.id,
    org_id: scope.org_id,
    company_id: scope.company_id,
    branch_id: row.branch_id ?? null,
    environment_type: scope.environment_type,
    is_demo: scope.is_demo,
    row_index: row.row_index,
    employee_code: row.employee_code,
    attendance_date: row.attendance_date,
    check_type: row.check_type,
    checked_at: row.checked_at,
    parsed_payload: row.parsed_payload,
    status: row.status,
    error_code: row.error_code,
    error_message: row.error_message,
    is_duplicate: row.is_duplicate,
    created_by: ctx.user_id,
    updated_by: ctx.user_id
  }));

  for (const batch_rows of chunk(rows_to_insert, 500)) {
    const { error } = await service.from("attendance_import_rows").insert(batch_rows);
    if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to stage import rows", 500);
  }

  return ok(schema_version, {
    batch,
    summary: {
      total_rows,
      valid_rows,
      invalid_rows,
      duplicate_rows
    },
    preview: staged_rows.slice(0, 100)
  }, 201);
}

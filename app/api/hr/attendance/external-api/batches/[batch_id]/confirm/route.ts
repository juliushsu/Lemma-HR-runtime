import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_write,
  reject_preview_override_write
} from "../../../../../_lib";
import { parse_attendance_date, parse_check_type, parse_datetime_iso } from "../../../../imports/_lib";
import {
  get_service_supabase,
  get_string_map,
  resolve_event_source_ref
} from "../../../_lib";

type ConfirmCorrection = {
  row_id: string;
  event_id?: string | null;
  source_ref?: string | null;
  employee_code?: string | null;
  external_employee_ref?: string | null;
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

function value_or<T>(override: T | undefined, base: T): T {
  return override === undefined ? base : override;
}

function normalize_correction_map(corrections: ConfirmCorrection[] | undefined) {
  const map = new Map<string, ConfirmCorrection>();
  for (const correction of corrections ?? []) {
    if (correction.row_id) map.set(correction.row_id, correction);
  }
  return map;
}

function get_payload_branch_ref(parsed_payload: Record<string, unknown> | null) {
  const raw = parsed_payload?.branch_ref;
  return raw === null || raw === undefined ? null : String(raw).trim() || null;
}

export async function POST(
  request: Request,
  { params }: { params: { batch_id: string } }
) {
  const schema_version = "hr.attendance.external.confirm.v1";
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
    .select("id,org_id,company_id,branch_id,environment_type,is_demo,status,source_type,source_registry_id")
    .eq("id", batch_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .eq("source_type", "external_api")
    .maybeSingle();

  if (batch_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch external import batch", 500);
  if (!batch) return fail(schema_version, "BATCH_NOT_FOUND", "External import batch not found", 404);
  if (batch.status === "imported") {
    return fail(schema_version, "BATCH_ALREADY_IMPORTED", "External import batch already imported", 409);
  }

  const { data: source, error: source_error } = batch.source_registry_id
    ? await service
        .from("attendance_source_registry")
        .select("id,branch_id,config_json")
        .eq("id", batch.source_registry_id)
        .maybeSingle()
    : { data: null, error: null };
  if (source_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch source registration", 500);
  if (!source) return fail(schema_version, "INTERNAL_ERROR", "source_registry_id is missing for this batch", 500);

  await service
    .from("attendance_import_batches")
    .update({ status: "importing", updated_at: new Date().toISOString(), updated_by: ctx.user_id })
    .eq("id", batch.id);

  const { data: rows, error: rows_error } = await service
    .from("attendance_import_rows")
    .select("id,row_index,event_id,source_ref,employee_code,external_employee_ref,attendance_date,check_type,checked_at,branch_id,parsed_payload,status,error_code,error_message")
    .eq("batch_id", batch.id)
    .order("row_index", { ascending: true });

  if (rows_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch external import rows", 500);
  if (!rows || rows.length === 0) return fail(schema_version, "EMPTY_BATCH", "Import batch has no rows", 400);

  const source_config = (source.config_json ?? {}) as Record<string, unknown>;
  const employee_ref_map = get_string_map(source_config.employee_ref_map);
  const branch_ref_map = get_string_map(source_config.branch_ref_map);

  const employee_codes = Array.from(
    new Set(
      rows
        .map((row) => {
          const correction = correction_map.get(row.id);
          const external_employee_ref = String(
            value_or(correction?.external_employee_ref, row.external_employee_ref ?? "") ?? ""
          ).trim();
          const explicit_employee_code = String(
            value_or(correction?.employee_code, row.employee_code ?? "") ?? ""
          ).trim();
          return explicit_employee_code || (external_employee_ref ? employee_ref_map[external_employee_ref] ?? "" : "");
        })
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
      .select("id")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .eq("environment_type", scope.environment_type)
  ]);

  if (employees_error || branches_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve employee/branch mapping", 500);
  }

  const employee_map = new Map((employees ?? []).map((employee) => [String(employee.employee_code), employee]));
  const branch_id_set = new Set((branches ?? []).map((branch) => String(branch.id)));

  const candidate_event_ids = Array.from(
    new Set(
      rows
        .map((row) => {
          const correction = correction_map.get(row.id);
          const event_id = value_or(correction?.event_id, row.event_id ?? null);
          return event_id ? String(event_id).trim() : null;
        })
        .filter((value): value is string => !!value)
    )
  );
  const candidate_source_refs = Array.from(
    new Set(
      rows
        .map((row) => {
          const correction = correction_map.get(row.id);
          const event_id = value_or(correction?.event_id, row.event_id ?? null);
          const source_ref = value_or(correction?.source_ref, row.source_ref ?? null);
          const resolved = resolve_event_source_ref(
            event_id ? String(event_id).trim() : null,
            source_ref ? String(source_ref).trim() : null
          );
          return resolved ? String(resolved) : null;
        })
        .filter((value): value is string => !!value)
    )
  );

  const [existing_audit_events, existing_audit_refs, existing_logs] = await Promise.all([
    candidate_event_ids.length > 0
      ? service
          .from("attendance_external_event_audits")
          .select("event_id")
          .eq("source_registry_id", source.id)
          .neq("batch_id", batch.id)
          .in("event_id", candidate_event_ids)
      : Promise.resolve({ data: [] as any[] }),
    candidate_source_refs.length > 0
      ? service
          .from("attendance_external_event_audits")
          .select("source_ref")
          .eq("source_registry_id", source.id)
          .neq("batch_id", batch.id)
          .in("source_ref", candidate_source_refs)
      : Promise.resolve({ data: [] as any[] }),
    candidate_source_refs.length > 0
      ? service
          .from("attendance_logs")
          .select("source_ref")
          .eq("org_id", scope.org_id)
          .eq("company_id", scope.company_id)
          .eq("environment_type", scope.environment_type)
          .eq("source_type", "external_api")
          .in("source_ref", candidate_source_refs)
      : Promise.resolve({ data: [] as any[] })
  ]);

  const existing_event_id_set = new Set((existing_audit_events.data ?? []).map((item) => String(item.event_id)));
  const existing_source_ref_set = new Set([
    ...(existing_audit_refs.data ?? []).map((item) => String(item.source_ref)),
    ...(existing_logs.data ?? []).map((item) => String(item.source_ref))
  ]);

  let imported_count = 0;
  let rejected_count = 0;
  let failed_count = 0;
  const failures: RowFailure[] = [];
  const processed_event_id_set = new Set<string>();
  const processed_source_ref_set = new Set<string>();

  for (const row of rows) {
    const correction = correction_map.get(row.id);
    const now_iso = new Date().toISOString();

    if (reject_set.has(row.id)) {
      rejected_count += 1;
      await service
        .from("attendance_import_rows")
        .update({
          status: "rejected",
          review_note: correction?.note ?? "Rejected by reviewer",
          reviewed_by: ctx.user_id,
          reviewed_at: now_iso,
          updated_at: now_iso,
          updated_by: ctx.user_id
        })
        .eq("id", row.id);

      await service
        .from("attendance_external_event_audits")
        .update({
          result_status: "rejected",
          failure_code: "REJECTED_BY_REVIEWER",
          failure_reason: correction?.note ?? "Rejected by reviewer",
          updated_at: now_iso
        })
        .eq("source_registry_id", source.id)
        .eq("batch_id", batch.id)
        .eq("row_id", row.id);
      continue;
    }

    const event_id_raw = value_or(correction?.event_id, row.event_id ?? null);
    const source_ref_raw = value_or(correction?.source_ref, row.source_ref ?? null);
    const event_id = event_id_raw ? String(event_id_raw).trim() : null;
    const source_ref = source_ref_raw ? String(source_ref_raw).trim() : null;
    const resolved_source_ref = resolve_event_source_ref(event_id, source_ref);

    const external_employee_ref = String(
      value_or(correction?.external_employee_ref, row.external_employee_ref ?? "") ?? ""
    ).trim();
    const explicit_employee_code = String(
      value_or(correction?.employee_code, row.employee_code ?? "") ?? ""
    ).trim();
    const resolved_employee_code = explicit_employee_code || (external_employee_ref ? employee_ref_map[external_employee_ref] ?? "" : "");
    const employee = resolved_employee_code ? employee_map.get(resolved_employee_code) ?? null : null;

    const check_type = parse_check_type(value_or(correction?.check_type, row.check_type ?? null));
    const checked_at_iso = parse_datetime_iso(value_or(correction?.checked_at, row.checked_at ?? null));
    const attendance_date = parse_attendance_date(
      value_or(correction?.attendance_date, row.attendance_date ?? null),
      checked_at_iso
    );

    const payload_branch_ref = get_payload_branch_ref((row.parsed_payload ?? null) as Record<string, unknown> | null);
    const raw_branch_id = value_or(correction?.branch_id, row.branch_id ?? null);
    const has_branch_hint = Boolean(raw_branch_id || payload_branch_ref);
    let branch_hint_unresolved = false;

    let branch_id: string | null = null;
    if (raw_branch_id) {
      branch_id = String(raw_branch_id);
      if (!branch_id_set.has(branch_id)) {
        branch_id = null;
        branch_hint_unresolved = true;
      }
    } else if (payload_branch_ref) {
      const mapped_branch_id = branch_ref_map[payload_branch_ref] ?? null;
      if (mapped_branch_id && branch_id_set.has(mapped_branch_id)) {
        branch_id = mapped_branch_id;
      } else {
        branch_hint_unresolved = true;
      }
    } else {
      if (employee?.branch_id) branch_id = String(employee.branch_id);
      if (!branch_id && source.branch_id) branch_id = String(source.branch_id);
    }

    if (!branch_id && has_branch_hint && branch_hint_unresolved) {
      branch_hint_unresolved = true;
    }

    let error_code: string | null = null;
    let error_message: string | null = null;

    if (!resolved_source_ref) {
      error_code = "INVALID_EVENT_REFERENCE";
      error_message = "event_id or source_ref is required";
    } else if (!employee) {
      error_code = "EMPLOYEE_UNRESOLVED";
      error_message = "employee_code/external_employee_ref cannot be resolved";
    } else if (!check_type) {
      error_code = "INVALID_CHECK_TYPE";
      error_message = "check_type must be check_in/check_out";
    } else if (!checked_at_iso || !attendance_date) {
      error_code = "INVALID_DATETIME";
      error_message = "checked_at/attendance_date is invalid";
    } else if (branch_hint_unresolved || !branch_id) {
      error_code = "BRANCH_UNRESOLVED";
      error_message = "branch cannot be resolved";
    }

    const is_duplicate =
      !error_code &&
      ((event_id && (processed_event_id_set.has(event_id) || existing_event_id_set.has(event_id))) ||
        (resolved_source_ref &&
          (processed_source_ref_set.has(resolved_source_ref) || existing_source_ref_set.has(resolved_source_ref))));
    if (!error_code && is_duplicate) {
      error_code = "DUPLICATE_EXTERNAL_EVENT";
      error_message = "duplicate external event detected";
    }

    if (event_id) processed_event_id_set.add(event_id);
    if (resolved_source_ref) processed_source_ref_set.add(resolved_source_ref);

    if (error_code || !employee || !check_type || !checked_at_iso || !attendance_date || !branch_id || !resolved_source_ref) {
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
          reviewed_at: now_iso,
          updated_at: now_iso,
          updated_by: ctx.user_id
        })
        .eq("id", row.id);

      await service
        .from("attendance_external_event_audits")
        .update({
          event_id: error_code === "DUPLICATE_EXTERNAL_EVENT" ? null : event_id,
          source_ref: error_code === "DUPLICATE_EXTERNAL_EVENT" ? null : resolved_source_ref,
          result_status: "failed",
          failure_code: error_code ?? "INVALID_ROW",
          failure_reason: error_message ?? "row failed validation",
          updated_at: now_iso
        })
        .eq("source_registry_id", source.id)
        .eq("batch_id", batch.id)
        .eq("row_id", row.id);
      continue;
    }

    const is_corrected = Boolean(correction);
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
        source_type: "external_api",
        source_ref: resolved_source_ref,
        status_code: is_corrected ? "manual_adjusted" : "normal",
        is_valid: true,
        is_adjusted: is_corrected,
        note: is_corrected
          ? `External API import corrected at confirm import (batch ${batch.id})`
          : `External API import (batch ${batch.id})`,
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
          updated_at: now_iso,
          updated_by: ctx.user_id
        })
        .eq("id", row.id);

      await service
        .from("attendance_external_event_audits")
        .update({
          event_id,
          source_ref: resolved_source_ref,
          result_status: "failed",
          failure_code: "IMPORT_WRITE_FAILED",
          failure_reason: "failed to write attendance log",
          updated_at: now_iso
        })
        .eq("source_registry_id", source.id)
        .eq("batch_id", batch.id)
        .eq("row_id", row.id);
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
          event_id,
          source_ref: resolved_source_ref,
          employee_code: resolved_employee_code,
          attendance_date,
          check_type,
          checked_at: checked_at_iso,
          branch_id
        },
        original_value: row.parsed_payload ?? {},
        reason: correction?.reason ?? "Manual correction during external API confirm import",
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

    await service
      .from("attendance_external_event_audits")
      .update({
        event_id,
        source_ref: resolved_source_ref,
        result_status: "imported",
        failure_code: null,
        failure_reason: null,
        updated_at: now_iso
      })
      .eq("source_registry_id", source.id)
      .eq("batch_id", batch.id)
      .eq("row_id", row.id);
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

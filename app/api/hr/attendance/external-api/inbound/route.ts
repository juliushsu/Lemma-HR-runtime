import { fail, ok } from "../../../_lib";
import { get_preview_context_override } from "../../../../_selected_context";
import {
  get_service_supabase,
  get_string_map,
  normalize_event_input,
  parse_inbound_events,
  resolve_event_source_ref,
  verify_bearer_token,
  verify_hmac_signature
} from "../_lib";
import { featureNotEnabledResponse, resolveFeatureAccess } from "../../../../../lib/featureGating";

type InboundRowErrorCode =
  | "EMPLOYEE_UNRESOLVED"
  | "INVALID_SIGNATURE_OR_AUTH"
  | "INVALID_DATETIME"
  | "DUPLICATE_EXTERNAL_EVENT"
  | "BRANCH_UNRESOLVED"
  | "INVALID_CHECK_TYPE"
  | "INVALID_EVENT_REFERENCE";

type InboundStagedRow = {
  row_index: number;
  event_id: string | null;
  source_ref: string | null;
  employee_code: string | null;
  external_employee_ref: string | null;
  attendance_date: string | null;
  check_type: string | null;
  checked_at: string | null;
  branch_id: string | null;
  parsed_payload: Record<string, unknown>;
  status: "valid" | "error";
  error_code: InboundRowErrorCode | null;
  error_message: string | null;
  is_duplicate: boolean;
};

export async function POST(request: Request) {
  const schema_version = "hr.attendance.external.inbound.v1";
  if (get_preview_context_override(request)) {
    return fail(schema_version, "PREVIEW_READ_ONLY", "Preview context override is read-only", 403);
  }
  const feature_key = "attendance.external_api.standard";
  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const raw_body = await request.text();
  if (!raw_body) return fail(schema_version, "INVALID_REQUEST", "Request body is required", 400);

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(raw_body) as Record<string, unknown>;
  } catch {
    return fail(schema_version, "INVALID_REQUEST", "Request body must be valid JSON", 400);
  }
  const source_id = request.headers.get("x-attendance-source-id") ?? String(payload.source_id ?? "").trim();
  const source_key = request.headers.get("x-attendance-source-key") ?? String(payload.source_key ?? "").trim();

  if (!source_id && !source_key) {
    return fail(schema_version, "INVALID_SIGNATURE_OR_AUTH", "Missing source identifier", 401);
  }

  let source_query = service.from("attendance_source_registry").select("*").eq("source_type", "external_api").eq("is_enabled", true);
  source_query = source_id ? source_query.eq("id", source_id) : source_query.eq("source_key", source_key);
  const { data: source_row, error: source_error } = await source_query.maybeSingle();
  if (source_error || !source_row) {
    return fail(schema_version, "INVALID_SIGNATURE_OR_AUTH", "Source is not registered or disabled", 401);
  }

  const source = source_row as any;
  const feature_access = await resolveFeatureAccess({
    org_id: String(source.org_id),
    feature_key
  });
  if (!feature_access.enabled) {
    return featureNotEnabledResponse(feature_key, 403);
  }

  if (source.auth_mode === "hmac_sha256") {
    const signature = request.headers.get("x-attendance-signature");
    if (!verify_hmac_signature(raw_body, String(source.credential ?? ""), signature)) {
      return fail(schema_version, "INVALID_SIGNATURE_OR_AUTH", "Invalid signature", 401);
    }
  } else if (source.auth_mode === "bearer_token") {
    if (!verify_bearer_token(request.headers.get("authorization"), String(source.credential ?? ""))) {
      return fail(schema_version, "INVALID_SIGNATURE_OR_AUTH", "Invalid bearer token", 401);
    }
  } else {
    return fail(schema_version, "INVALID_SIGNATURE_OR_AUTH", "Unsupported auth mode", 401);
  }

  const events = parse_inbound_events(payload);
  if (events.length === 0) {
    return fail(schema_version, "INVALID_REQUEST", "events payload is empty", 400);
  }

  const config = (source.config_json ?? {}) as Record<string, unknown>;
  const employee_ref_map = get_string_map(config.employee_ref_map);
  const branch_ref_map = get_string_map(config.branch_ref_map);

  const normalized_rows = events.map((event, idx) => normalize_event_input(idx + 1, event));
  const candidate_employee_codes = Array.from(
    new Set(
      normalized_rows
        .map((row) => row.employee_code || (row.external_employee_ref ? employee_ref_map[row.external_employee_ref] ?? null : null))
        .filter((value): value is string => !!value)
    )
  );
  const candidate_event_ids = Array.from(new Set(normalized_rows.map((row) => row.event_id).filter((value): value is string => !!value)));
  const candidate_source_refs = Array.from(
    new Set(normalized_rows.map((row) => resolve_event_source_ref(row.event_id, row.source_ref)).filter((value): value is string => !!value))
  );

  const [{ data: employees, error: employees_error }, { data: branches, error: branches_error }] = await Promise.all([
    candidate_employee_codes.length > 0
      ? service
          .from("employees")
          .select("id,employee_code,branch_id")
          .eq("org_id", source.org_id)
          .eq("company_id", source.company_id)
          .eq("environment_type", source.environment_type)
          .in("employee_code", candidate_employee_codes)
      : Promise.resolve({ data: [] as any[], error: null }),
    service
      .from("branches")
      .select("id")
      .eq("org_id", source.org_id)
      .eq("company_id", source.company_id)
      .eq("environment_type", source.environment_type)
  ]);

  if (employees_error || branches_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve employee/branch mapping", 500);
  }

  const employee_map = new Map((employees ?? []).map((employee) => [String(employee.employee_code), employee]));
  const branch_id_set = new Set((branches ?? []).map((branch) => String(branch.id)));

  const existing_event_id_set = new Set<string>();
  const existing_source_ref_set = new Set<string>();
  if (candidate_event_ids.length > 0) {
    const { data } = await service
      .from("attendance_external_event_audits")
      .select("event_id")
      .eq("source_registry_id", source.id)
      .in("event_id", candidate_event_ids);
    for (const item of data ?? []) {
      if (item.event_id) existing_event_id_set.add(String(item.event_id));
    }
  }
  if (candidate_source_refs.length > 0) {
    const { data: existing_refs } = await service
      .from("attendance_external_event_audits")
      .select("source_ref")
      .eq("source_registry_id", source.id)
      .in("source_ref", candidate_source_refs);
    for (const item of existing_refs ?? []) {
      if (item.source_ref) existing_source_ref_set.add(String(item.source_ref));
    }

    const { data: existing_logs } = await service
      .from("attendance_logs")
      .select("source_ref")
      .eq("org_id", source.org_id)
      .eq("company_id", source.company_id)
      .eq("environment_type", source.environment_type)
      .eq("source_type", "external_api")
      .in("source_ref", candidate_source_refs);
    for (const item of existing_logs ?? []) {
      if (item.source_ref) existing_source_ref_set.add(String(item.source_ref));
    }
  }

  const seen_event_id_set = new Set<string>();
  const seen_source_ref_set = new Set<string>();
  const staged_rows: InboundStagedRow[] = [];

  for (const row of normalized_rows) {
    const resolved_source_ref = resolve_event_source_ref(row.event_id, row.source_ref);
    const resolved_employee_code =
      row.employee_code || (row.external_employee_ref ? employee_ref_map[row.external_employee_ref] ?? null : null);
    const resolved_employee = resolved_employee_code ? employee_map.get(resolved_employee_code) ?? null : null;
    const payload_branch_ref =
      row.parsed_payload.branch_ref && String(row.parsed_payload.branch_ref).trim()
        ? String(row.parsed_payload.branch_ref).trim()
        : null;
    const has_branch_hint = Boolean(row.branch_id || payload_branch_ref);
    let branch_hint_unresolved = false;

    let resolved_branch_id: string | null = null;
    if (row.branch_id) {
      if (branch_id_set.has(row.branch_id)) {
        resolved_branch_id = row.branch_id;
      } else {
        branch_hint_unresolved = true;
      }
    } else if (payload_branch_ref) {
      const mapped_branch_id = branch_ref_map[payload_branch_ref] ?? null;
      if (mapped_branch_id && branch_id_set.has(mapped_branch_id)) {
        resolved_branch_id = mapped_branch_id;
      } else {
        branch_hint_unresolved = true;
      }
    } else {
      if (resolved_employee?.branch_id) resolved_branch_id = String(resolved_employee.branch_id);
      if (!resolved_branch_id && source.branch_id) resolved_branch_id = String(source.branch_id);
    }

    if (!resolved_branch_id && has_branch_hint && branch_hint_unresolved) {
      branch_hint_unresolved = true;
    }

    let error_code: InboundRowErrorCode | null = null;
    let error_message: string | null = null;

    if (!resolved_source_ref) {
      error_code = "INVALID_EVENT_REFERENCE";
      error_message = "event_id or source_ref is required";
    } else if (!resolved_employee) {
      error_code = "EMPLOYEE_UNRESOLVED";
      error_message = "employee_code/external_employee_ref cannot be resolved";
    } else if (!row.check_type) {
      error_code = "INVALID_CHECK_TYPE";
      error_message = "check_type must be check_in/check_out";
    } else if (!row.checked_at || !row.attendance_date) {
      error_code = "INVALID_DATETIME";
      error_message = "checked_at/attendance_date is invalid";
    } else if (branch_hint_unresolved || !resolved_branch_id) {
      error_code = "BRANCH_UNRESOLVED";
      error_message = "branch cannot be resolved";
    }

    const is_duplicate =
      (!error_code &&
        ((row.event_id && (seen_event_id_set.has(row.event_id) || existing_event_id_set.has(row.event_id))) ||
          (resolved_source_ref &&
            (seen_source_ref_set.has(resolved_source_ref) || existing_source_ref_set.has(resolved_source_ref))))) ||
      false;

    if (!error_code && is_duplicate) {
      error_code = "DUPLICATE_EXTERNAL_EVENT";
      error_message = "duplicate external event detected";
    }

    if (row.event_id) seen_event_id_set.add(row.event_id);
    if (resolved_source_ref) seen_source_ref_set.add(resolved_source_ref);

    staged_rows.push({
      row_index: row.row_index,
      event_id: row.event_id,
      source_ref: resolved_source_ref,
      employee_code: resolved_employee_code,
      external_employee_ref: row.external_employee_ref,
      attendance_date: row.attendance_date,
      check_type: row.check_type,
      checked_at: row.checked_at,
      branch_id: resolved_branch_id,
      parsed_payload: row.parsed_payload,
      status: error_code ? "error" : "valid",
      error_code,
      error_message,
      is_duplicate: error_code === "DUPLICATE_EXTERNAL_EVENT"
    });
  }

  const total_rows = staged_rows.length;
  const valid_rows = staged_rows.filter((row) => row.status === "valid").length;
  const invalid_rows = total_rows - valid_rows;
  const duplicate_rows = staged_rows.filter((row) => row.error_code === "DUPLICATE_EXTERNAL_EVENT").length;

  const { data: batch, error: batch_error } = await service
    .from("attendance_import_batches")
    .insert({
      org_id: source.org_id,
      company_id: source.company_id,
      branch_id: source.branch_id,
      environment_type: source.environment_type,
      is_demo: source.is_demo,
      source_type: "external_api",
      source_registry_id: source.id,
      sync_mode: "inbound",
      file_name: `external-inbound-${Date.now()}.json`,
      file_type: "json",
      status: "preview_ready",
      total_rows,
      valid_rows,
      invalid_rows,
      duplicate_rows,
      imported_rows: 0
    })
    .select("id,source_type,source_registry_id,file_name,file_type,status,total_rows,valid_rows,invalid_rows,duplicate_rows,imported_rows,created_at")
    .maybeSingle();

  if (batch_error || !batch) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create external import batch", 500);
  }

  const { data: inserted_rows, error: insert_rows_error } = await service
    .from("attendance_import_rows")
    .insert(
      staged_rows.map((row) => ({
        batch_id: batch.id,
        org_id: source.org_id,
        company_id: source.company_id,
        branch_id: row.branch_id,
        environment_type: source.environment_type,
        is_demo: source.is_demo,
        row_index: row.row_index,
        employee_code: row.employee_code,
        external_employee_ref: row.external_employee_ref,
        attendance_date: row.attendance_date,
        check_type: row.check_type,
        checked_at: row.checked_at,
        event_id: row.event_id,
        source_ref: row.source_ref,
        parsed_payload: row.parsed_payload,
        status: row.status,
        error_code: row.error_code,
        error_message: row.error_message,
        is_duplicate: row.is_duplicate
      }))
    )
    .select("id,row_index,event_id,source_ref,status,error_code,error_message,parsed_payload,branch_id");

  if (insert_rows_error || !inserted_rows) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to stage external import rows", 500);
  }

  const inserted_by_row_index = new Map(inserted_rows.map((row) => [Number(row.row_index), row]));
  const audit_event_dedupe = new Set<string>();
  const audit_source_ref_dedupe = new Set<string>();

  const audit_rows = staged_rows.map((row) => {
    const inserted = inserted_by_row_index.get(row.row_index);
    const result_status =
      row.status === "valid" ? "preview_valid" : row.error_code === "DUPLICATE_EXTERNAL_EVENT" ? "duplicate" : "preview_error";

    const dedupe_event = row.event_id && !audit_event_dedupe.has(row.event_id) ? row.event_id : null;
    const dedupe_source_ref = row.source_ref && !audit_source_ref_dedupe.has(row.source_ref) ? row.source_ref : null;
    if (dedupe_event) audit_event_dedupe.add(dedupe_event);
    if (dedupe_source_ref) audit_source_ref_dedupe.add(dedupe_source_ref);

    return {
      source_registry_id: source.id,
      batch_id: batch.id,
      row_id: inserted?.id ?? null,
      org_id: source.org_id,
      company_id: source.company_id,
      branch_id: row.branch_id,
      environment_type: source.environment_type,
      is_demo: source.is_demo,
      event_id: dedupe_event,
      source_ref: dedupe_source_ref,
      dedupe_key: `${row.event_id ?? ""}|${row.source_ref ?? ""}`,
      event_type: "attendance",
      result_status,
      failure_code: row.error_code,
      failure_reason: row.error_message,
      payload: row.parsed_payload
    };
  });

  if (audit_rows.length > 0) {
    const { error: audit_error } = await service.from("attendance_external_event_audits").insert(audit_rows);
    if (audit_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to write external event audits", 500);
  }

  return ok(
    schema_version,
    {
      source: {
        id: source.id,
        source_key: source.source_key,
        source_name: source.source_name
      },
      batch,
      summary: {
        total_rows,
        valid_rows,
        invalid_rows,
        duplicate_rows
      },
      preview: staged_rows.slice(0, 100)
    },
    201
  );
}

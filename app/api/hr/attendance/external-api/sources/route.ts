import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_read,
  can_write,
  parse_pagination,
  reject_preview_override_write
} from "../../../_lib";
import { get_service_supabase } from "../_lib";

const AUTH_MODES = new Set(["hmac_sha256", "bearer_token"]);

function sanitize_source_key(input: string) {
  return input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 64);
}

export async function GET(request: Request) {
  const schema_version = "hr.attendance.external.source.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const { page, page_size, from, to } = parse_pagination(request);
  const { data, count, error } = await service
    .from("attendance_source_registry")
    .select("id,source_type,source_key,source_name,auth_mode,config_json,is_enabled,last_validated_at,branch_id,created_at,updated_at", {
      count: "exact"
    })
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .eq("source_type", "external_api")
    .order("created_at", { ascending: false })
    .range(from, to);

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch source registrations", 500);

  return ok(schema_version, {
    items: data ?? [],
    pagination: {
      page,
      page_size,
      total: count ?? 0
    }
  });
}

export async function POST(request: Request) {
  const schema_version = "hr.attendance.external.source.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
  const source_name = String(body.source_name ?? "").trim();
  const auth_mode = String(body.auth_mode ?? "hmac_sha256").trim();
  const credential = String(body.credential ?? "").trim();
  const source_key_input = String(body.source_key ?? source_name).trim();
  const source_key = sanitize_source_key(source_key_input || `external_api_${Date.now()}`);
  const branch_id = body.branch_id ? String(body.branch_id) : null;
  const is_enabled = body.is_enabled === undefined ? true : Boolean(body.is_enabled);
  const config_json = body.config_json && typeof body.config_json === "object" && !Array.isArray(body.config_json)
    ? (body.config_json as Record<string, unknown>)
    : {};

  if (!source_name || !credential || !source_key) {
    return fail(schema_version, "INVALID_REQUEST", "source_name, source_key and credential are required", 400);
  }
  if (!AUTH_MODES.has(auth_mode)) {
    return fail(schema_version, "INVALID_REQUEST", "auth_mode must be hmac_sha256 or bearer_token", 400);
  }

  if (branch_id) {
    const { data: matched_branch } = await service
      .from("branches")
      .select("id")
      .eq("id", branch_id)
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .eq("environment_type", scope.environment_type)
      .maybeSingle();
    if (!matched_branch) return fail(schema_version, "INVALID_REQUEST", "branch_id is not in current scope", 400);
  }

  const { data, error } = await service
    .from("attendance_source_registry")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      source_type: "external_api",
      source_key,
      source_name,
      auth_mode,
      credential,
      config_json,
      is_enabled,
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id,source_type,source_key,source_name,auth_mode,config_json,is_enabled,branch_id,created_at,updated_at")
    .maybeSingle();

  if (error) {
    if (String(error.message ?? "").toLowerCase().includes("duplicate") || error.code === "23505") {
      return fail(schema_version, "DUPLICATE_SOURCE_KEY", "source_key already exists in this scope", 409);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create source registration", 500);
  }

  return ok(schema_version, { source: data }, 201);
}

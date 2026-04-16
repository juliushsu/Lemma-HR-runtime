import { ok, fail, get_access_context, resolve_scope, can_read, can_write, apply_scope, reject_preview_override_write } from "../../../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

const PROFICIENCY_LEVELS = new Set(["basic", "conversational", "business", "native"]);
const SKILL_TYPES = new Set(["spoken", "written", "reading", "other"]);

function is_uuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

function normalize_db_error_message(input: unknown) {
  return String(input ?? "").trim().toUpperCase();
}

async function resolve_scoped_employee(ctx: Awaited<ReturnType<typeof get_access_context>>, scope: NonNullable<ReturnType<typeof resolve_scope>>, ref: string) {
  const query = apply_scope(
    ctx.supabase
      .from("employees")
      .select("id,employee_code,org_id,company_id,environment_type,is_demo,branch_id"),
    scope
  );

  const { data, error } = is_uuid(ref)
    ? await query.eq("id", ref).maybeSingle()
    : await query.eq("employee_code", ref).maybeSingle();

  return { data, error };
}

export async function GET(request: Request, { params }: Params) {
  const schema_version = "hr.employee.language_skills.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const { id: ref } = await params;
  if (!ref) return fail(schema_version, "INVALID_REQUEST", "employee ref is required", 400);

  const { data: employee, error: employee_error } = await resolve_scoped_employee(ctx, scope, ref);
  if (employee_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  const { data: items, error } = await ctx.supabase.rpc("list_employee_language_skills", {
    p_employee_id_or_code: employee.id
  });

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to list language skills", 500);

  return ok(schema_version, {
    employee_id: employee.id,
    employee_code: employee.employee_code,
    items: (items ?? []).map((row: any) => ({
      id: row.id,
      employee_id: row.employee_id,
      employee_code: row.employee_code,
      language_code: row.language_code,
      proficiency_level: row.proficiency_level,
      skill_type: row.skill_type,
      is_primary: row.is_primary,
      updated_at: row.updated_at
    }))
  });
}

export async function POST(request: Request, { params }: Params) {
  const schema_version = "hr.employee.language_skills.upsert.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const { id: ref } = await params;
  if (!ref) return fail(schema_version, "INVALID_REQUEST", "employee ref is required", 400);

  const { data: employee, error: employee_error } = await resolve_scoped_employee(ctx, scope, ref);
  if (employee_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
  const language_code = String(body.language_code ?? "").trim().toLowerCase();
  const proficiency_level = String(body.proficiency_level ?? "").trim();
  const skill_type = String(body.skill_type ?? "").trim();
  const is_primary = Boolean(body.is_primary ?? false);

  if (!language_code || !proficiency_level || !skill_type) {
    return fail(
      schema_version,
      "INVALID_REQUEST",
      "language_code, proficiency_level and skill_type are required",
      400
    );
  }
  if (!PROFICIENCY_LEVELS.has(proficiency_level)) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid proficiency_level", 400);
  }
  if (!SKILL_TYPES.has(skill_type)) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid skill_type", 400);
  }

  const payload = {
    employee_id_or_code: employee.id,
    org_id: scope.org_id,
    company_id: scope.company_id,
    environment_type: scope.environment_type,
    actor_user_id: ctx.user_id,
    language_code,
    proficiency_level,
    skill_type,
    is_primary
  };

  const { data: rows, error } = await ctx.supabase.rpc("upsert_employee_language_skill", {
    p_payload: payload
  });

  if (error) {
    const code = normalize_db_error_message(error.message);
    if (
      code.includes("EMPLOYEE_NOT_FOUND") ||
      code.includes("EMPLOYEE_CODE_AMBIGUOUS") ||
      code.includes("EMPLOYEE_REF_REQUIRED")
    ) {
      return fail(schema_version, "INVALID_EMPLOYEE_REFERENCE", "Employee reference is invalid", 400);
    }
    if (code.includes("PROFICIENCY_LEVEL_REQUIRED") || code.includes("SKILL_TYPE_REQUIRED") || code.includes("LANGUAGE_CODE_REQUIRED")) {
      return fail(schema_version, "INVALID_REQUEST", "Required fields are missing", 400);
    }
    if (code.includes("ACTOR_USER_REQUIRED") || code.includes("ACTOR_USER_MISMATCH")) {
      return fail(schema_version, "SCOPE_FORBIDDEN", "Actor permission is invalid", 403);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to upsert language skill", 500);
  }

  const row = (rows ?? [])[0] ?? null;
  return ok(schema_version, {
    employee_id: employee.id,
    employee_code: employee.employee_code,
    item: row
      ? {
          id: row.id,
          employee_id: row.employee_id,
          employee_code: row.employee_code,
          language_code: row.language_code,
          proficiency_level: row.proficiency_level,
          skill_type: row.skill_type,
          is_primary: row.is_primary,
          updated_at: row.updated_at
        }
      : null
  });
}

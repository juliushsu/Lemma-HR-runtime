import { ok, fail, get_access_context, resolve_scope, can_write, apply_scope, reject_preview_override_write } from "../../../../_lib";

type Params = {
  params: Promise<{ id: string; skill_id: string }>;
};

function is_uuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

async function resolve_scoped_employee(ctx: Awaited<ReturnType<typeof get_access_context>>, scope: NonNullable<ReturnType<typeof resolve_scope>>, ref: string) {
  const query = apply_scope(
    ctx.supabase
      .from("employees")
      .select("id,employee_code,org_id,company_id,environment_type"),
    scope
  );

  const { data, error } = is_uuid(ref)
    ? await query.eq("id", ref).maybeSingle()
    : await query.eq("employee_code", ref).maybeSingle();

  return { data, error };
}

export async function DELETE(request: Request, { params }: Params) {
  const schema_version = "hr.employee.language_skills.delete.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const { id: ref, skill_id } = await params;
  if (!ref || !skill_id) return fail(schema_version, "INVALID_REQUEST", "employee ref and skill_id are required", 400);
  if (!is_uuid(skill_id)) return fail(schema_version, "INVALID_REQUEST", "skill_id must be UUID", 400);

  const { data: employee, error: employee_error } = await resolve_scoped_employee(ctx, scope, ref);
  if (employee_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  const { data: target_skill, error: skill_error } = await ctx.supabase
    .from("employee_language_skills")
    .select("id,employee_id,org_id,company_id,environment_type")
    .eq("id", skill_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .maybeSingle();

  if (skill_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch language skill", 500);
  if (!target_skill || target_skill.employee_id !== employee.id) {
    return fail(schema_version, "LANGUAGE_SKILL_NOT_FOUND", "Language skill not found", 404);
  }

  const { data: rows, error } = await ctx.supabase.rpc("delete_employee_language_skill", {
    p_skill_id: skill_id,
    p_actor_user_id: ctx.user_id
  });

  if (error) {
    const code = String(error.message ?? "").trim().toUpperCase();
    if (code.includes("DELETE_PERMISSION_DENIED") || code.includes("ACTOR_USER_REQUIRED") || code.includes("ACTOR_USER_MISMATCH")) {
      return fail(schema_version, "SCOPE_FORBIDDEN", "Not allowed to delete language skill", 403);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to delete language skill", 500);
  }

  const row = (rows ?? [])[0] ?? null;
  return ok(schema_version, {
    employee_id: employee.id,
    employee_code: employee.employee_code,
    deleted: Boolean(row?.deleted ?? false),
    skill_id
  });
}

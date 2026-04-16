import { ok, fail, get_access_context, resolve_scope, can_read, can_write, apply_scope, reject_preview_override_write } from "../_lib";

export async function GET(request: Request) {
  const schema_version = "hr.department.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const { data, error } = await apply_scope(
    ctx.supabase
      .from("departments")
      .select("id,department_code,department_name,parent_department_id,manager_employee_id,is_active,sort_order"),
    scope
  ).order("sort_order", { ascending: true });

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch departments", 500);
  return ok(schema_version, { items: data ?? [] });
}

export async function POST(request: Request) {
  const schema_version = "hr.department.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const body = (await request.json()) as Record<string, unknown>;
  const department_code = String(body.department_code ?? "").trim();
  const department_name = String(body.department_name ?? "").trim();
  if (!department_code || !department_name) {
    return fail(schema_version, "INVALID_REQUEST", "department_code and department_name are required", 400);
  }

  if (body.manager_employee_id) {
    const { data: manager } = await apply_scope(
      ctx.supabase.from("employees").select("id"),
      scope
    ).eq("id", body.manager_employee_id).maybeSingle();
    if (!manager) return fail(schema_version, "INVALID_MANAGER_REFERENCE", "Manager employee is not found", 400);
  }

  if (body.parent_department_id) {
    const { data: parent } = await apply_scope(
      ctx.supabase.from("departments").select("id"),
      scope
    ).eq("id", body.parent_department_id).maybeSingle();
    if (!parent) return fail(schema_version, "DEPARTMENT_NOT_FOUND", "Parent department not found", 404);
  }

  const { data, error } = await ctx.supabase
    .from("departments")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: (body.branch_id as string | null) ?? scope.branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      department_code,
      department_name,
      parent_department_id: body.parent_department_id ?? null,
      manager_employee_id: body.manager_employee_id ?? null,
      sort_order: Number(body.sort_order ?? 100),
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id")
    .maybeSingle();

  if (error) {
    if ((error as { code?: string }).code === "23505") {
      return fail(schema_version, "DEPARTMENT_CODE_ALREADY_EXISTS", "Department code already exists", 409);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create department", 500);
  }

  return ok(schema_version, { department_id: data?.id ?? null }, 201);
}

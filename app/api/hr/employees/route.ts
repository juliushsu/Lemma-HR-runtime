import { ok, fail, get_access_context, resolve_scope, can_read, can_write, apply_scope, parse_pagination, get_display_name, reject_preview_override_write } from "../_lib";

const EMPLOYMENT_TYPES = new Set(["full_time", "part_time", "contractor", "intern", "temporary"]);
const EMPLOYMENT_STATUSES = new Set(["active", "inactive", "on_leave", "terminated"]);

function isStagingRuntime() {
  const values = [
    process.env.APP_ENV,
    process.env.NEXT_PUBLIC_APP_ENV,
    process.env.DEPLOY_TARGET
  ]
    .filter(Boolean)
    .map((v) => String(v).toLowerCase());

  return values.some((v) => v === "staging" || v.includes("staging"));
}

function addDebugHeaders(
  response: Response,
  payload: {
    auth_user_id?: string | null;
    membership_role?: string | null;
    org_id?: string | null;
    company_id?: string | null;
    environment_type?: string | null;
  }
) {
  if (!isStagingRuntime()) return response;

  response.headers.set("x-debug-auth-user-id", payload.auth_user_id ?? "");
  response.headers.set("x-debug-membership-role", payload.membership_role ?? "");
  response.headers.set("x-debug-org-id", payload.org_id ?? "");
  response.headers.set("x-debug-company-id", payload.company_id ?? "");
  response.headers.set("x-debug-environment-type", payload.environment_type ?? "");
  return response;
}

function pickMembershipRole(
  memberships: Array<{
    org_id: string;
    company_id: string | null;
    branch_id: string | null;
    role: string;
    scope_type: string;
    environment_type: string;
  }>,
  scope: {
    org_id: string;
    company_id: string;
    branch_id: string | null;
    environment_type: string;
  }
) {
  const matched = memberships.find((m) => {
    if (m.org_id !== scope.org_id) return false;
    if (m.environment_type !== scope.environment_type) return false;
    if (m.company_id && m.company_id !== scope.company_id) return false;

    if (m.scope_type === "org") return true;
    if (m.scope_type === "company") return m.company_id === scope.company_id;
    if (m.scope_type === "branch") return m.company_id === scope.company_id && m.branch_id === scope.branch_id;
    if (m.scope_type === "self") return true;
    return false;
  });

  return matched?.role ?? memberships[0]?.role ?? null;
}

export async function GET(request: Request) {
  const schema_version = "hr.employee.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    const fallbackMembership = ctx.memberships[0] ?? null;
    const response = fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
    return addDebugHeaders(response, {
      auth_user_id: ctx.user_id,
      membership_role: fallbackMembership?.role ?? null,
      org_id: fallbackMembership?.org_id ?? null,
      company_id: fallbackMembership?.company_id ?? null,
      environment_type: fallbackMembership?.environment_type ?? null
    });
  }

  const url = new URL(request.url);
  const { page, page_size, from, to } = parse_pagination(request);
  const keyword = url.searchParams.get("keyword");
  const department_id = url.searchParams.get("department_id");
  const position_id = url.searchParams.get("position_id");
  const employment_status = url.searchParams.get("employment_status");
  const employment_type = url.searchParams.get("employment_type");
  const sort_by = url.searchParams.get("sort_by") ?? "created_at";
  const sort_order = (url.searchParams.get("sort_order") ?? "desc").toLowerCase() === "asc" ? "asc" : "desc";

  const sortable = new Set(["created_at", "updated_at", "employee_code", "legal_name", "hire_date"]);
  const order_column = sortable.has(sort_by) ? sort_by : "created_at";

  let query = ctx.supabase
    .from("employees")
    .select("*", { count: "exact" })
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type);

  if (scope.branch_id) query = query.eq("branch_id", scope.branch_id);
  if (keyword) {
    const escaped = keyword.replace(/,/g, " ");
    query = query.or(
      `employee_code.ilike.%${escaped}%,legal_name.ilike.%${escaped}%,preferred_name.ilike.%${escaped}%,display_name.ilike.%${escaped}%,work_email.ilike.%${escaped}%`
    );
  }
  if (department_id) query = query.eq("department_id", department_id);
  if (position_id) query = query.eq("position_id", position_id);
  if (employment_status) query = query.eq("employment_status", employment_status);
  if (employment_type) query = query.eq("employment_type", employment_type);

  const { data: employees, count, error } = await query.order(order_column, { ascending: sort_order === "asc" }).range(from, to);
  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employees", 500);

  const department_ids = Array.from(new Set((employees ?? []).map((e) => e.department_id).filter(Boolean)));
  const position_ids = Array.from(new Set((employees ?? []).map((e) => e.position_id).filter(Boolean)));
  const manager_ids = Array.from(new Set((employees ?? []).map((e) => e.manager_employee_id).filter(Boolean)));

  const [{ data: departments }, { data: positions }, { data: managers }] = await Promise.all([
    department_ids.length > 0
      ? apply_scope(ctx.supabase.from("departments").select("id,department_code,department_name"), scope).in("id", department_ids)
      : Promise.resolve({ data: [] as Array<Record<string, unknown>> }),
    position_ids.length > 0
      ? apply_scope(ctx.supabase.from("positions").select("id,position_code,position_name"), scope).in("id", position_ids)
      : Promise.resolve({ data: [] as Array<Record<string, unknown>> }),
    manager_ids.length > 0
      ? apply_scope(ctx.supabase.from("employees").select("id,employee_code,display_name,preferred_name,legal_name"), scope).in("id", manager_ids)
      : Promise.resolve({ data: [] as Array<Record<string, unknown>> })
  ]);

  const department_map = new Map((departments ?? []).map((d) => [d.id, d]));
  const position_map = new Map((positions ?? []).map((p) => [p.id, p]));
  const manager_map = new Map((managers ?? []).map((m) => [m.id, m]));

  const items = (employees ?? []).map((employee) => {
    const department = employee.department_id ? department_map.get(employee.department_id) ?? null : null;
    const position = employee.position_id ? position_map.get(employee.position_id) ?? null : null;
    const manager = employee.manager_employee_id ? manager_map.get(employee.manager_employee_id) ?? null : null;

    return {
      id: employee.id,
      employee_code: employee.employee_code,
      legal_name: employee.legal_name,
      preferred_name: employee.preferred_name,
      display_name: get_display_name(employee),
      family_name_local: employee.family_name_local,
      given_name_local: employee.given_name_local,
      full_name_local: employee.full_name_local,
      family_name_latin: employee.family_name_latin,
      given_name_latin: employee.given_name_latin,
      full_name_latin: employee.full_name_latin,
      work_email: employee.work_email,
      mobile_phone: employee.mobile_phone,
      department: department
        ? {
            id: department.id,
            department_code: department.department_code,
            department_name: department.department_name
          }
        : null,
      position: position
        ? {
            id: position.id,
            position_code: position.position_code,
            position_name: position.position_name
          }
        : null,
      manager: manager
        ? {
            id: manager.id,
            employee_code: manager.employee_code,
            display_name: get_display_name(manager as { display_name: string | null; preferred_name: string | null; legal_name: string | null })
          }
        : null,
      employment_type: employee.employment_type,
      employment_status: employee.employment_status,
      hire_date: employee.hire_date,
      preferred_locale: employee.preferred_locale,
      branch_id: employee.branch_id
    };
  });

  const response = ok(schema_version, {
    items,
    pagination: {
      page,
      page_size,
      total: count ?? 0
    }
  });

  return addDebugHeaders(response, {
    auth_user_id: ctx.user_id,
    membership_role: pickMembershipRole(ctx.memberships, scope),
    org_id: scope.org_id,
    company_id: scope.company_id,
    environment_type: scope.environment_type
  });
}

export async function POST(request: Request) {
  const schema_version = "hr.employee.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const body = (await request.json()) as Record<string, unknown>;
  const employee_code = String(body.employee_code ?? "").trim();
  const legal_name = String(body.legal_name ?? "").trim();
  const employment_type = String(body.employment_type ?? "");
  const employment_status = String(body.employment_status ?? "");

  if (!employee_code || !legal_name) {
    return fail(schema_version, "INVALID_REQUEST", "employee_code and legal_name are required", 400);
  }
  if (!EMPLOYMENT_TYPES.has(employment_type)) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid employment_type", 400);
  }
  if (!EMPLOYMENT_STATUSES.has(employment_status)) {
    return fail(schema_version, "INVALID_EMPLOYMENT_STATUS", "Invalid employment_status", 400);
  }

  if (body.manager_employee_id) {
    const { data: manager } = await apply_scope(
      ctx.supabase.from("employees").select("id"),
      scope
    ).eq("id", body.manager_employee_id).maybeSingle();
    if (!manager) return fail(schema_version, "INVALID_MANAGER_REFERENCE", "Manager employee is not found", 400);
  }

  const insert_payload = {
    org_id: scope.org_id,
    company_id: scope.company_id,
    branch_id: (body.branch_id as string | null) ?? scope.branch_id,
    environment_type: scope.environment_type,
    is_demo: scope.is_demo,
    employee_code,
    legal_name,
    preferred_name: body.preferred_name ?? null,
    display_name: body.display_name ?? null,
    work_email: body.work_email ?? null,
    personal_email: body.personal_email ?? null,
    mobile_phone: body.mobile_phone ?? null,
    nationality_code: body.nationality_code ?? null,
    work_country_code: body.work_country_code ?? null,
    preferred_locale: body.preferred_locale ?? null,
    timezone: body.timezone ?? null,
    department_id: body.department_id ?? null,
    position_id: body.position_id ?? null,
    manager_employee_id: body.manager_employee_id ?? null,
    employment_type,
    employment_status,
    hire_date: body.hire_date ?? null,
    termination_date: body.termination_date ?? null,
    gender_note: body.gender_note ?? null,
    notes: body.notes ?? null,
    created_by: ctx.user_id,
    updated_by: ctx.user_id
  };

  const { data, error } = await ctx.supabase.from("employees").insert(insert_payload).select("id").maybeSingle();
  if (error) {
    if ((error as { code?: string }).code === "23505") {
      return fail(schema_version, "EMPLOYEE_CODE_ALREADY_EXISTS", "Employee code already exists", 409);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create employee", 500);
  }

  return ok(schema_version, { employee_id: data?.id ?? null }, 201);
}

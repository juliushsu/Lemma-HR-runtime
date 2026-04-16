import { ok, fail, get_access_context, resolve_scope, can_read, can_write, apply_scope, get_display_name, reject_preview_override_write } from "../../_lib";

const EMPLOYMENT_STATUSES = new Set(["active", "inactive", "on_leave", "terminated"]);

type Params = {
  params: Promise<{ id: string }>;
};

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

export async function GET(request: Request, { params }: Params) {
  const schema_version = "hr.employee.detail.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const { id } = await params;
  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const scopedEmployees = apply_scope(ctx.supabase.from("employees").select("*"), scope);
  const { data: employee, error } = isUuid(id)
    ? await scopedEmployees.eq("id", id).maybeSingle()
    : await scopedEmployees.eq("employee_code", id).maybeSingle();
  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  const [{ data: department }, { data: position }, { data: manager }, { data: assignment }] = await Promise.all([
    employee.department_id
      ? apply_scope(
          ctx.supabase.from("departments").select("id,department_code,department_name"),
          scope
        ).eq("id", employee.department_id).maybeSingle()
      : Promise.resolve({ data: null }),
    employee.position_id
      ? apply_scope(
          ctx.supabase.from("positions").select("id,position_code,position_name,job_level"),
          scope
        ).eq("id", employee.position_id).maybeSingle()
      : Promise.resolve({ data: null }),
    employee.manager_employee_id
      ? apply_scope(
          ctx.supabase.from("employees").select("id,employee_code,display_name,preferred_name,legal_name,full_name_local,full_name_latin"),
          scope
        ).eq("id", employee.manager_employee_id).maybeSingle()
      : Promise.resolve({ data: null }),
    apply_scope(
      ctx.supabase.from("employee_assignments").select("id,assignment_type,effective_from,effective_to,is_current"),
      scope
    )
      .eq("employee_id", employee.id)
      .eq("is_current", true)
      .order("effective_from", { ascending: false })
      .limit(1)
      .maybeSingle()
  ]);

  return ok(schema_version, {
    employee: {
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
      department_name: department?.department_name ?? null,
      position_title: position?.position_name ?? null,
      manager_name: manager
        ? (manager.full_name_local ?? get_display_name(manager) ?? manager.full_name_latin ?? manager.employee_code)
        : null,
      work_email: employee.work_email,
      personal_email: employee.personal_email,
      mobile_phone: employee.mobile_phone,
      nationality_code: employee.nationality_code,
      work_country_code: employee.work_country_code,
      preferred_locale: employee.preferred_locale,
      timezone: employee.timezone,
      department_id: employee.department_id,
      position_id: employee.position_id,
      manager_employee_id: employee.manager_employee_id,
      employment_type: employee.employment_type,
      employment_status: employee.employment_status,
      hire_date: employee.hire_date,
      termination_date: employee.termination_date,
      gender_note: employee.gender_note,
      notes: employee.notes
    },
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
          position_name: position.position_name,
          job_level: position.job_level
        }
      : null,
    manager: manager
      ? {
          id: manager.id,
          employee_code: manager.employee_code,
          display_name: get_display_name(manager)
        }
      : null,
    current_assignment: assignment
      ? {
          id: assignment.id,
          assignment_type: assignment.assignment_type,
          effective_from: assignment.effective_from,
          effective_to: assignment.effective_to,
          is_current: assignment.is_current
        }
      : null
  });
}

export async function PATCH(request: Request, { params }: Params) {
  const schema_version = "hr.employee.update.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const { id } = await params;
  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const body = (await request.json()) as Record<string, unknown>;
  const allowed = new Set([
    "preferred_name",
    "display_name",
    "work_email",
    "personal_email",
    "mobile_phone",
    "nationality_code",
    "work_country_code",
    "preferred_locale",
    "timezone",
    "department_id",
    "position_id",
    "manager_employee_id",
    "employment_type",
    "employment_status",
    "hire_date",
    "termination_date",
    "gender_note",
    "notes",
    "branch_id"
  ]);

  const update_payload: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(body)) {
    if (allowed.has(key)) update_payload[key] = value;
  }

  if (Object.keys(update_payload).length === 0) {
    return fail(schema_version, "INVALID_REQUEST", "No updatable fields provided", 400);
  }

  if (update_payload.employment_status && !EMPLOYMENT_STATUSES.has(String(update_payload.employment_status))) {
    return fail(schema_version, "INVALID_EMPLOYMENT_STATUS", "Invalid employment_status", 400);
  }

  if (update_payload.manager_employee_id) {
    if (String(update_payload.manager_employee_id) === id) {
      return fail(schema_version, "INVALID_MANAGER_REFERENCE", "Employee cannot report to self", 400);
    }
    const { data: manager } = await apply_scope(
      ctx.supabase.from("employees").select("id"),
      scope
    ).eq("id", update_payload.manager_employee_id).maybeSingle();
    if (!manager) return fail(schema_version, "INVALID_MANAGER_REFERENCE", "Manager employee is not found", 400);
  }

  update_payload.updated_by = ctx.user_id;
  update_payload.updated_at = new Date().toISOString();

  const { data, error } = await apply_scope(
    ctx.supabase.from("employees"),
    scope
  ).update(update_payload).eq("id", id).select("id").maybeSingle();

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to update employee", 500);
  if (!data) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  return ok(schema_version, { employee_id: data.id });
}

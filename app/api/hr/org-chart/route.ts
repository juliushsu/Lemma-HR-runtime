import { ok, fail, get_access_context, resolve_scope, can_read, apply_scope, get_display_name } from "../_lib";

const UNASSIGNED_DEPARTMENT_ID = "__org_chart_unassigned__";

export async function GET(request: Request) {
  const schema_version = "hr.org_chart.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const url = new URL(request.url);
  const view_type = url.searchParams.get("view_type") ?? "department_tree";
  if (!["department_tree", "reporting_lines"].includes(view_type)) {
    return fail(schema_version, "INVALID_REQUEST", "view_type must be department_tree or reporting_lines", 400);
  }

  const [{ data: departments, error: department_error }, { data: employees, error: employee_error }, { data: positions }] =
    await Promise.all([
      apply_scope(
        ctx.supabase
          .from("departments")
          .select("id,department_code,department_name,parent_department_id,manager_employee_id,is_active,sort_order"),
        scope
      ).order("sort_order", { ascending: true }),
      apply_scope(
        ctx.supabase
          .from("employees")
          .select(
            "id,employee_code,display_name,preferred_name,legal_name,family_name_local,given_name_local,full_name_local,family_name_latin,given_name_latin,full_name_latin,department_id,position_id,manager_employee_id,employment_status"
          ),
        scope
      ).order("employee_code", { ascending: true }),
      apply_scope(ctx.supabase.from("positions").select("id,position_name"), scope)
    ]);

  if (department_error || employee_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch org chart", 500);
  }

  const manager_ids = Array.from(new Set((departments ?? []).map((d) => d.manager_employee_id).filter(Boolean)));
  const { data: managers } =
    manager_ids.length > 0
      ? await apply_scope(
          ctx.supabase.from("employees").select("id,employee_code,display_name,preferred_name,legal_name"),
          scope
        ).in("id", manager_ids)
      : { data: [] };

  const manager_map = new Map((managers ?? []).map((m) => [m.id, m]));
  const position_map = new Map((positions ?? []).map((p) => [p.id, p.position_name]));

  const members = (employees ?? []).map((e) => ({
    id: e.id,
    employee_code: e.employee_code,
    display_name: get_display_name(e),
    full_name_local: e.full_name_local,
    full_name_latin: e.full_name_latin,
    position_name: e.position_id ? (position_map.get(e.position_id) ?? null) : null,
    employment_status: e.employment_status,
    manager_employee_id: e.manager_employee_id,
    department_id: e.department_id
  }));

  const members_by_department = new Map<string, Array<(typeof members)[number]>>();
  const unassigned_members: Array<(typeof members)[number]> = [];
  for (const member of members) {
    if (!member.department_id) {
      unassigned_members.push(member);
      continue;
    }
    const current = members_by_department.get(member.department_id) ?? [];
    current.push(member);
    members_by_department.set(member.department_id, current);
  }
  for (const group of members_by_department.values()) {
    group.sort((a, b) => a.employee_code.localeCompare(b.employee_code));
  }
  unassigned_members.sort((a, b) => a.employee_code.localeCompare(b.employee_code));

  const departments_with_members = (departments ?? []).map((d) => {
    const manager = d.manager_employee_id ? manager_map.get(d.manager_employee_id) ?? null : null;
    return {
      id: d.id,
      department_code: d.department_code,
      department_name: d.department_name,
      parent_department_id: d.parent_department_id,
      manager: manager
        ? {
            id: manager.id,
            employee_code: manager.employee_code,
            display_name: get_display_name(manager)
          }
        : null,
      members: members_by_department.get(d.id) ?? []
    };
  });

  if (departments_with_members.length === 0 && members.length > 0) {
    departments_with_members.push({
      id: UNASSIGNED_DEPARTMENT_ID,
      department_code: "UNASSIGNED",
      department_name: "Unassigned",
      parent_department_id: null,
      manager: null,
      members
    });
  } else if (unassigned_members.length > 0) {
    departments_with_members.push({
      id: UNASSIGNED_DEPARTMENT_ID,
      department_code: "UNASSIGNED",
      department_name: "Unassigned",
      parent_department_id: null,
      manager: null,
      members: unassigned_members
    });
  }

  const manager_links = members
    .filter((m) => m.manager_employee_id)
    .map((m) => ({
      manager_employee_id: m.manager_employee_id,
      report_employee_id: m.id
    }));

  return ok(schema_version, {
    view_type,
    departments: departments_with_members,
    reporting_lines: {
      members,
      manager_links
    }
  });
}

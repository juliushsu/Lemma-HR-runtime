import {
  ok,
  fail,
  get_access_context,
  resolve_scope,
  can_read,
  apply_scope,
  get_display_name
} from "../../_lib";
import { resolve_attendance_boundary } from "../_boundary";

export async function GET(request: Request) {
  const schema_version = "hr.attendance.context.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const url = new URL(request.url);
  const employee_id = url.searchParams.get("employee_id");

  const employee_query = apply_scope(
    ctx.supabase.from("employees").select("id,employee_code,display_name,preferred_name,legal_name,branch_id"),
    scope
  );
  const { data: employee, error: employee_error } = employee_id
    ? await employee_query.eq("id", employee_id).maybeSingle()
    : await employee_query.eq("employment_status", "active").order("created_at", { ascending: true }).limit(1).maybeSingle();

  if (employee_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found in scope", 404);

  const { data: current_assignment, error: assignment_error } = await apply_scope(
    ctx.supabase.from("employee_assignments").select("branch_id,is_current,effective_from"),
    scope
  )
    .eq("employee_id", employee.id)
    .eq("is_current", true)
    .order("effective_from", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (assignment_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee assignment", 500);

  const employee_default_branch_id = employee.branch_id ?? current_assignment?.branch_id ?? null;

  const [{ data: location, error: location_error }, { data: company_settings, error: company_error }, { data: boundaries, error: boundaries_error }] =
    await Promise.all([
      employee_default_branch_id
        ? ctx.supabase
            .from("branches")
            .select("id,name,latitude,longitude,is_attendance_enabled")
            .eq("org_id", scope.org_id)
            .eq("company_id", scope.company_id)
            .eq("environment_type", scope.environment_type)
            .eq("id", employee_default_branch_id)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      ctx.supabase
        .from("company_settings")
        .select("is_attendance_enabled")
        .eq("org_id", scope.org_id)
        .eq("company_id", scope.company_id)
        .eq("environment_type", scope.environment_type)
        .maybeSingle(),
      ctx.supabase
        .from("attendance_boundary_settings")
        .select("branch_id,checkin_radius_m,is_attendance_enabled")
        .eq("org_id", scope.org_id)
        .eq("company_id", scope.company_id)
        .eq("environment_type", scope.environment_type)
    ]);

  if (location_error || company_error || boundaries_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve attendance boundary context", 500);
  }

  const resolved_boundary = resolve_attendance_boundary({
    boundaries,
    resolved_branch_id: employee_default_branch_id,
    location_is_attendance_enabled: location?.is_attendance_enabled ?? null,
    company_is_attendance_enabled: company_settings?.is_attendance_enabled ?? null
  });

  return ok(schema_version, {
    employee: {
      id: employee.id,
      employee_code: employee.employee_code,
      display_name: get_display_name(employee),
      default_branch_id: employee_default_branch_id
    },
    location: employee_default_branch_id
      ? {
          branch_id: employee_default_branch_id,
          location_name: location?.name ?? null,
          latitude: location?.latitude ?? null,
          longitude: location?.longitude ?? null
        }
      : null,
    attendance_boundary: {
      checkin_radius_m: resolved_boundary.checkin_radius_m,
      is_attendance_enabled: resolved_boundary.is_attendance_enabled
    },
    resolve_rule: {
      order: ["company_default", "branch_override"],
      resolved_from: resolved_boundary.resolved_from,
      company_is_attendance_enabled: resolved_boundary.company_enabled,
      location_is_attendance_enabled: resolved_boundary.location_enabled,
      company_default: resolved_boundary.company_default
        ? {
            checkin_radius_m: resolved_boundary.company_default.checkin_radius_m,
            is_attendance_enabled: resolved_boundary.company_default.is_attendance_enabled
          }
        : null,
      branch_override: resolved_boundary.branch_override
        ? {
            branch_id: resolved_boundary.branch_override.branch_id,
            checkin_radius_m: resolved_boundary.branch_override.checkin_radius_m,
            is_attendance_enabled: resolved_boundary.branch_override.is_attendance_enabled
          }
        : null
    }
  });
}

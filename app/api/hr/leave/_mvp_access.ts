import { AccessContext, Scope, can_write, fail } from "../_lib";
import { list_leave_scoped_employees, resolve_leave_request_employee } from "./_locale";

export async function load_leave_mvp_scope_access(
  service: any,
  ctx: AccessContext,
  scope: Scope,
  schema_version: string,
  requested_employee_id: string | null = null
) {
  const { data: employees, error } = await list_leave_scoped_employees(service, scope);
  if (error) {
    return {
      response: fail(schema_version, "INTERNAL_ERROR", "Failed to resolve scoped employees", 500),
      data: null
    };
  }

  const actor_employee = resolve_leave_request_employee(employees, null, ctx.user_email);
  const requested_employee = requested_employee_id
    ? employees.find((employee) => employee.id === requested_employee_id) ?? null
    : null;

  return {
    response: null,
    data: {
      employees,
      actor_employee,
      requested_employee,
      can_manage_scope: can_write(ctx, scope)
    }
  };
}

export function resolve_leave_mvp_list_employee_filter(
  schema_version: string,
  access: {
    can_manage_scope: boolean;
    actor_employee: { id: string } | null;
    requested_employee: { id: string } | null;
  },
  requested_employee_id: string | null
) {
  if (access.can_manage_scope) {
    if (requested_employee_id && !access.requested_employee) {
      return {
        response: fail(
          schema_version,
          "EMPLOYEE_NOT_FOUND",
          "Failed to resolve leave requester within the selected context",
          400
        ),
        employee_id: null
      };
    }

    return {
      response: null,
      employee_id: access.requested_employee?.id ?? null
    };
  }

  if (!access.actor_employee) {
    return {
      response: fail(
        schema_version,
        "EMPLOYEE_CONTEXT_REQUIRED",
        "Employee context is required for self-service leave history",
        400
      ),
      employee_id: null
    };
  }

  if (requested_employee_id && requested_employee_id !== access.actor_employee.id) {
    return {
      response: fail(
        schema_version,
        "SELF_SERVICE_SCOPE_FORBIDDEN",
        "Self-service leave history cannot access another employee",
        403
      ),
      employee_id: null
    };
  }

  return {
    response: null,
    employee_id: access.actor_employee.id
  };
}

export function can_access_leave_mvp_request(
  access: {
    can_manage_scope: boolean;
    actor_employee: { id: string } | null;
  },
  employee_id: string
) {
  return access.can_manage_scope || access.actor_employee?.id === employee_id;
}

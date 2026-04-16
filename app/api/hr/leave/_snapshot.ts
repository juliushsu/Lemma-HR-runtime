import { createClient } from "@supabase/supabase-js";
import { fail } from "../_lib";
import { list_leave_scoped_employees, resolve_leave_locale_hint } from "./_locale";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

export function get_leave_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

export async function load_leave_request_snapshot(
  service: any,
  scope: any,
  user_id: string,
  leave_request_id: string,
  schema_version = "hr.leave_request_mvp.detail.v1"
) {
  const { data: leave_request, error: leave_error } = await service
    .from("leave_requests")
    .select("id,employee_id,leave_type,reason,start_at,end_at,status,current_step,created_at")
    .eq("id", leave_request_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .maybeSingle();

  if (leave_error) {
    return {
      response: fail(schema_version, "INTERNAL_ERROR", "Failed to fetch leave request detail", 500),
      data: null
    };
  }
  if (!leave_request) {
    return {
      response: fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404),
      data: null
    };
  }

  const { data: employees, error: employees_error } = await list_leave_scoped_employees(service, scope);
  if (employees_error) {
    return {
      response: fail(schema_version, "INTERNAL_ERROR", "Failed to resolve scoped employees", 500),
      data: null
    };
  }

  const employee = employees.find((item) => item.id === leave_request.employee_id) ?? null;
  const locale_hint = await resolve_leave_locale_hint(service, scope, employee, user_id);

  const { data: approval_steps, error: steps_error } = await service
    .from("leave_approval_steps")
    .select("id,step_order,approver_employee_id,status,acted_at,comment")
    .eq("request_id", leave_request_id)
    .order("step_order", { ascending: true });

  if (steps_error) {
    return {
      response: fail(schema_version, "INTERNAL_ERROR", "Failed to fetch leave approval steps", 500),
      data: null
    };
  }

  const approverEmployeeIds = Array.from(
    new Set((approval_steps ?? []).map((step: any) => step.approver_employee_id).filter(Boolean))
  );

  const { data: approvers, error: approvers_error } =
    approverEmployeeIds.length > 0
      ? await service
          .from("employees")
          .select("id,employee_code,display_name,preferred_name,legal_name")
          .in("id", approverEmployeeIds)
      : { data: [], error: null };

  if (approvers_error) {
    return {
      response: fail(schema_version, "INTERNAL_ERROR", "Failed to fetch approver snapshot", 500),
      data: null
    };
  }

  const approverMap = new Map(
    (approvers ?? []).map((approver: any) => [
      approver.id,
      {
        id: approver.id,
        employee_code: approver.employee_code,
        display_name: approver.display_name ?? approver.preferred_name ?? approver.legal_name ?? null
      }
    ])
  );

  return {
    response: null,
    data: {
      id: leave_request.id,
      employee_id: leave_request.employee_id,
      leave_type: leave_request.leave_type,
      reason: leave_request.reason,
      start_at: leave_request.start_at,
      end_at: leave_request.end_at,
      status: leave_request.status ?? "pending",
      current_step: leave_request.current_step ?? 0,
      created_at: leave_request.created_at,
      resolved_locale: locale_hint.resolved_locale,
      locale_source: locale_hint.locale_source,
      approval_steps: (approval_steps ?? []).map((step: any) => ({
        id: step.id,
        step_order: step.step_order,
        approver_employee_id: step.approver_employee_id,
        approver: approverMap.get(step.approver_employee_id) ?? null,
        status: step.status ?? "pending",
        acted_at: step.acted_at,
        comment: step.comment
      }))
    }
  };
}

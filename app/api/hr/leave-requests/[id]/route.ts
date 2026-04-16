import { createClient } from "@supabase/supabase-js";
import { fail, ok } from "../../_lib";
import { get_leave_read_context } from "../../leave/_lib";
import {
  list_leave_scoped_employees,
  resolve_leave_locale_hint
} from "../../leave/_locale";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

type Params = {
  params: Promise<{ id: string }>;
};

function get_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

export async function GET(request: Request, { params }: Params) {
  const schema_version = "hr.leave_request_mvp.detail.v1";
  const { response, ctx, scope } = await get_leave_read_context(request);
  if (response || !ctx || !scope) return response;

  const { id } = await params;
  if (!id) {
    return fail(schema_version, "INVALID_REQUEST", "Leave request id is required", 400);
  }

  const service = get_service_supabase();
  if (!service) {
    return fail(schema_version, "CONFIG_MISSING", "Supabase service role config is missing", 500);
  }

  const { data: leave_request, error: leave_error } = await service
    .from("leave_requests")
    .select("id,employee_id,leave_type,reason,start_at,end_at,status,current_step,created_at")
    .eq("id", id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .maybeSingle();

  if (leave_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch leave request detail", 500);
  }
  if (!leave_request) {
    return fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404);
  }

  const { data: employees, error: employees_error } = await list_leave_scoped_employees(service, scope);
  if (employees_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve scoped employees", 500);
  }

  const employee = employees.find((item) => item.id === leave_request.employee_id) ?? null;
  const locale_hint = await resolve_leave_locale_hint(service, scope, employee, ctx.user_id);

  const { data: approval_steps, error: steps_error } = await service
    .from("leave_approval_steps")
    .select("id,step_order,approver_employee_id,status,acted_at,comment")
    .eq("request_id", id)
    .order("step_order", { ascending: true });

  if (steps_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch leave approval steps", 500);
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
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch approver snapshot", 500);
  }

  const approverMap = new Map(
    (approvers ?? []).map((employee: any) => [
      employee.id,
      {
        id: employee.id,
        employee_code: employee.employee_code,
        display_name: employee.display_name ?? employee.preferred_name ?? employee.legal_name ?? null
      }
    ])
  );

  return ok(schema_version, {
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
  });
}

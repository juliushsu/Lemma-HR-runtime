import { fail, ok } from "../../../_lib";
import { get_leave_write_context } from "../../../leave/_lib";
import { get_leave_service_supabase, load_leave_request_snapshot } from "../../../leave/_snapshot";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, { params }: Params) {
  const schema_version = "hr.leave_request_mvp.approve.v1";
  const { response, ctx, scope } = await get_leave_write_context(request);
  if (response || !ctx || !scope) return response;

  const { id } = await params;
  if (!id) {
    return fail(schema_version, "INVALID_REQUEST", "Leave request id is required", 400);
  }

  const service = get_leave_service_supabase();
  if (!service) {
    return fail(schema_version, "CONFIG_MISSING", "Supabase service role config is missing", 500);
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    body = {};
  }

  const approver_employee_id = String(body.approver_employee_id ?? "").trim();
  const comment = String(body.comment ?? "").trim() || null;
  if (!approver_employee_id) {
    return fail(schema_version, "APPROVER_EMPLOYEE_REQUIRED", "approver_employee_id is required", 400);
  }

  const { data: leave_request, error: request_error } = await service
    .from("leave_requests")
    .select("id,status,current_step,approval_status")
    .eq("id", id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .maybeSingle();

  if (request_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch leave request", 500);
  }
  if (!leave_request) {
    return fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404);
  }
  if ((leave_request.status ?? leave_request.approval_status) !== "pending") {
    return fail(schema_version, "LEAVE_REQUEST_NOT_PENDING", "Leave request is not pending", 409);
  }

  const { data: steps, error: steps_error } = await service
    .from("leave_approval_steps")
    .select("id,step_order,approver_employee_id,status")
    .eq("request_id", id)
    .order("step_order", { ascending: true });

  if (steps_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch approval steps", 500);
  }

  const current_step = (steps ?? []).find((step: any) => step.step_order === (leave_request.current_step ?? 0)) ?? null;
  if (!current_step) {
    return fail(schema_version, "CURRENT_STEP_NOT_FOUND", "Current approval step is not found", 400);
  }
  if (current_step.approver_employee_id !== approver_employee_id) {
    return fail(schema_version, "APPROVER_MISMATCH", "Only the current approver may approve this request", 403);
  }

  const acted_at = new Date().toISOString();
  const { error: step_update_error } = await service
    .from("leave_approval_steps")
    .update({
      status: "approved",
      acted_at,
      comment
    })
    .eq("id", current_step.id);

  if (step_update_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to update current approval step", 500);
  }

  const next_step = (steps ?? []).find((step: any) => step.step_order === (leave_request.current_step ?? 0) + 1) ?? null;
  const request_patch = next_step
    ? {
        current_step: (leave_request.current_step ?? 0) + 1,
        status: "pending",
        approval_status: "pending",
        updated_at: acted_at
      }
    : {
        status: "approved",
        approval_status: "approved",
        approved_at: acted_at,
        updated_at: acted_at
      };

  const { data: updated_request, error: request_update_error } = await service
    .from("leave_requests")
    .update(request_patch)
    .eq("id", id)
    .select("id,status,current_step")
    .maybeSingle();

  if (request_update_error || !updated_request) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to update leave request", 500);
  }

  const { response: snapshot_error, data } = await load_leave_request_snapshot(
    service,
    scope,
    ctx.user_id,
    id,
    schema_version
  );
  if (snapshot_error || !data) return snapshot_error;

  return ok(schema_version, data);
}

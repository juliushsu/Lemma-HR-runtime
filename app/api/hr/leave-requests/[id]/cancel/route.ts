import { fail, ok } from "../../../_lib";
import { get_leave_write_context } from "../../../leave/_lib";
import { get_leave_service_supabase, load_leave_request_snapshot } from "../../../leave/_snapshot";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, { params }: Params) {
  const schema_version = "hr.leave_request_mvp.cancel.v1";
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

  const { data: leave_request, error: request_error } = await service
    .from("leave_requests")
    .select("id,status,approval_status")
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
  if ((leave_request.status ?? leave_request.approval_status) === "cancelled") {
    return fail(schema_version, "LEAVE_REQUEST_ALREADY_CANCELLED", "Leave request is already cancelled", 409);
  }

  const cancelled_at = new Date().toISOString();
  const { error: cancel_error } = await service
    .from("leave_requests")
    .update({
      status: "cancelled",
      approval_status: "cancelled",
      updated_at: cancelled_at,
      updated_by: ctx.user_id
    })
    .eq("id", id);

  if (cancel_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to cancel leave request", 500);
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

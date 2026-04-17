import { fail, ok } from "../../_lib";
import { get_leave_read_context } from "../../leave/_lib";
import { can_access_leave_mvp_request, load_leave_mvp_scope_access } from "../../leave/_mvp_access";
import { get_leave_service_supabase, load_leave_request_snapshot } from "../../leave/_snapshot";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, { params }: Params) {
  const schema_version = "hr.leave_request_mvp.detail.v1";
  const { response, ctx, scope } = await get_leave_read_context(request);
  if (response || !ctx || !scope) return response;

  const { id } = await params;
  if (!id) {
    return fail(schema_version, "INVALID_REQUEST", "Leave request id is required", 400);
  }

  const service = get_leave_service_supabase();
  if (!service) {
    return fail(schema_version, "CONFIG_MISSING", "Supabase service role config is missing", 500);
  }

  const access_result = await load_leave_mvp_scope_access(service, ctx, scope, schema_version);
  if (access_result.response || !access_result.data) return access_result.response;

  const { data: leave_request, error: leave_error } = await service
    .from("leave_requests")
    .select("id,employee_id")
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
  if (!can_access_leave_mvp_request(access_result.data, leave_request.employee_id)) {
    return fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404);
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

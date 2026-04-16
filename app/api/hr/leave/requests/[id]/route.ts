import { fail } from "../../../_lib";
import { get_leave_read_context, get_scoped_leave_request, map_leave_rpc_error, ok_with_meta } from "../../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, { params }: Params) {
  const schema_version = "hr.leave.request.detail.v1";
  const { response, ctx, scope } = await get_leave_read_context(request);
  if (response || !ctx || !scope) return response;

  const { id } = await params;
  if (!id) return fail(schema_version, "INVALID_REQUEST", "Leave request id is required", 400);

  const scoped = await get_scoped_leave_request(ctx, scope, id);
  if (scoped.error) {
    return map_leave_rpc_error(schema_version, scoped.error, "Failed to verify leave request scope");
  }
  if (!scoped.data) {
    return fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404);
  }

  const { data, error } = await ctx.supabase.rpc("get_leave_request_detail", {
    p_leave_request_id: id
  });

  if (error) {
    return map_leave_rpc_error(schema_version, error, "Failed to fetch leave request detail");
  }
  if (!data) {
    return fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404);
  }

  return ok_with_meta(schema_version, data);
}

import { fail } from "../../../../_lib";
import { get_leave_write_context, get_scoped_leave_request, map_leave_rpc_error, ok_with_meta } from "../../../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, { params }: Params) {
  const schema_version = "hr.leave.request.approve.v1";
  const { response, ctx, scope } = await get_leave_write_context(request);
  if (response || !ctx || !scope) return response;

  const { id } = await params;
  if (!id) return fail(schema_version, "INVALID_REQUEST", "Leave request id is required", 400);

  const scoped = await get_scoped_leave_request(ctx, scope, id);
  if (scoped.error) return map_leave_rpc_error(schema_version, scoped.error, "Failed to verify leave request scope");
  if (!scoped.data) return fail(schema_version, "LEAVE_REQUEST_NOT_FOUND", "Leave request is not found", 404);

  let body: { reason?: unknown } = {};
  try {
    body = (await request.json()) as { reason?: unknown };
  } catch {}

  const reason = typeof body.reason === "string" ? body.reason.trim() || null : null;

  const { data, error } = await ctx.supabase.rpc("approve_leave_request", {
    p_leave_request_id: id,
    p_approver_user_id: ctx.user_id,
    p_reason: reason
  });

  if (error) return map_leave_rpc_error(schema_version, error, "Failed to approve leave request");

  return ok_with_meta(schema_version, {
    leave_request: Array.isArray(data) ? data[0] ?? null : data
  });
}

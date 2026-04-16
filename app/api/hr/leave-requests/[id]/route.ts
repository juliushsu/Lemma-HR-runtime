import { fail, ok } from "../../_lib";
import { get_leave_read_context } from "../../leave/_lib";
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

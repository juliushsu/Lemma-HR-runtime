import { get_scoped_context, success, failure } from "../_attendance_phase1";
import { list_source_items } from "./_lib";

export async function GET(request: Request) {
  const scoped = await get_scoped_context(request, { write: false });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const { items, error } = await list_source_items(ctx, scope);
  if (error) return failure("INTERNAL_ERROR", "Failed to fetch attendance sources", 500, { detail: error });

  return success({
    org_id: scope.org_id,
    company_id: scope.company_id,
    items: items ?? []
  });
}

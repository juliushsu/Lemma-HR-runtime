import { fail } from "../../../hr/_lib";
import { ensure_portal_access, ok } from "../../_lib";
import { load_compliance_detail_item } from "../_lib";

type Params = {
  params: Promise<{ item_id: string }>;
};

export async function GET(request: Request, { params }: Params) {
  const schema_version = "portal.compliance_detail.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const { item_id } = await params;
  const detail = await load_compliance_detail_item(access.ctx, access.scope, item_id);
  if (!detail) return fail(schema_version, "COMPLIANCE_ITEM_NOT_FOUND", "Compliance item not found", 404);

  return ok(schema_version, {
    org_id: access.scope.org_id,
    company_id: access.scope.company_id,
    detail,
    // camelCase alias for frontend adapters.
    detailItem: detail
  });
}

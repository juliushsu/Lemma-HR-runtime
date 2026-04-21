import { fail, get_access_context, ok, resolve_scope, scopedQuery } from "../../_lib";
import {
  can_read_governance,
  get_staging_fallback_governance_check,
  map_governance_check,
  should_use_staging_fallback
} from "../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, { params }: Params) {
  const schema_version = "legal.governance_checks.detail.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(request, ctx);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);
  if (!can_read_governance(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Governance checks are not accessible", 403);
  }

  const { id } = await params;

  const { data, error } = await scopedQuery(
    ctx.supabase
      .from("legal_governance_checks")
      .select(
        [
          "id",
          "domain",
          "check_type",
          "target_object_type",
          "target_object_id",
          "jurisdiction_code",
          "rule_strength",
          "title",
          "statutory_minimum_json",
          "company_current_value_json",
          "ai_suggested_value_json",
          "deviation_type",
          "severity",
          "company_decision_status",
          "impact_domain",
          "reason_summary",
          "source_ref_json",
          "created_by_source",
          "created_at",
          "updated_at"
        ].join(","),
      ),
    scope
  )
    .eq("id", id)
    .maybeSingle();

  if (error) {
    const fallback = should_use_staging_fallback(error) ? get_staging_fallback_governance_check(scope, id) : null;
    if (fallback) return ok(schema_version, { item: fallback });
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch governance check", 500);
  }
  if (!data) {
    const fallback = get_staging_fallback_governance_check(scope, id);
    if (fallback) return ok(schema_version, { item: fallback });
    return fail(schema_version, "GOVERNANCE_CHECK_NOT_FOUND", "Governance check not found", 404);
  }

  return ok(schema_version, {
    item: map_governance_check(data)
  });
}

import { fail, get_access_context, ok, resolve_scope, scopedQuery } from "../_lib";
import {
  ALLOWED_DOMAINS,
  ALLOWED_SEVERITIES,
  ALLOWED_STATUSES,
  can_read_governance,
  list_staging_fallback_governance_checks,
  map_governance_check,
  parse_enum_param,
  parse_pagination,
  should_use_staging_fallback
} from "./_lib";

export async function GET(request: Request) {
  const schema_version = "legal.governance_checks.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(request, ctx);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);
  if (!can_read_governance(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Governance checks are not accessible", 403);
  }

  const url = new URL(request.url);
  const { page, page_size, from, to } = parse_pagination(url);
  const check_type = url.searchParams.get("check_type")?.trim() ?? null;
  const target_object_type = url.searchParams.get("target_object_type")?.trim() ?? null;
  const jurisdiction_code = url.searchParams.get("jurisdiction_code")?.trim().toUpperCase() ?? null;

  const domain = parse_enum_param(url.searchParams.get("domain"), ALLOWED_DOMAINS, "domain");
  if (domain.error) return fail(schema_version, "INVALID_REQUEST", domain.error, 400);

  const severity = parse_enum_param(url.searchParams.get("severity"), ALLOWED_SEVERITIES, "severity");
  if (severity.error) return fail(schema_version, "INVALID_REQUEST", severity.error, 400);

  const rawStatus = url.searchParams.get("status");
  const status = rawStatus?.trim().toLowerCase() === "all"
    ? { value: null, error: null }
    : parse_enum_param(rawStatus, ALLOWED_STATUSES, "status");
  if (status.error) return fail(schema_version, "INVALID_REQUEST", status.error, 400);

  let query = scopedQuery(
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
        { count: "exact" }
      )
      .order("updated_at", { ascending: false })
      .range(from, to),
    scope
  );

  if (domain.value) query = query.eq("domain", domain.value);
  if (severity.value) query = query.eq("severity", severity.value);
  if (status.value) query = query.eq("company_decision_status", status.value);
  if (jurisdiction_code) query = query.eq("jurisdiction_code", jurisdiction_code);
  if (check_type) query = query.eq("check_type", check_type);
  if (target_object_type) query = query.eq("target_object_type", target_object_type);

  const { data, count, error } = await query;
  if (error) {
    const fallback = should_use_staging_fallback(error)
      ? list_staging_fallback_governance_checks(
          scope,
          {
            domain: domain.value,
            severity: severity.value,
            status: status.value,
            jurisdiction_code,
            check_type,
            target_object_type
          },
          { page, page_size, from, to }
        )
      : null;
    if (fallback) return ok(schema_version, fallback);

    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch governance checks", 500);
  }

  return ok(schema_version, {
    items: (data ?? []).map(map_governance_check),
    pagination: {
      page,
      page_size,
      total: count ?? 0
    }
  });
}

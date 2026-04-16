import { fail, get_access_context, ok } from "../../hr/_lib";
import { FEATURE_KEYS, getOrganizationCurrentPlan, resolveFeatureAccess } from "../../../lib/featureGating";

const ALLOWED_ROLES = new Set(["owner", "super_admin", "admin"]);

export async function GET(request: Request) {
  const schema_version = "system.current_plan.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const { data: user_profile } = await ctx.supabase
    .from("users")
    .select("security_role")
    .eq("id", ctx.user_id)
    .maybeSingle();
  if (user_profile?.security_role === "org_super_admin") {
    return fail(schema_version, "SCOPE_FORBIDDEN", "System governance is not accessible", 403);
  }

  const url = new URL(request.url);
  const requested_org_id = url.searchParams.get("org_id");

  const memberships = ctx.memberships ?? [];
  const allowed_memberships = memberships.filter((m) => ALLOWED_ROLES.has(m.role));
  if (allowed_memberships.length === 0) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Current plan is not accessible", 403);
  }

  const selected_org_id = ctx.current_context?.org_id ?? null;
  if (selected_org_id && requested_org_id && requested_org_id !== selected_org_id) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Requested org does not match selected context", 403);
  }

  const org_id = requested_org_id ?? selected_org_id ?? null;
  if (!org_id) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Selected context is not available", 403);
  }

  const membership_for_org = allowed_memberships.find((m) => m.org_id === org_id);
  if (!membership_for_org) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Requested org is not accessible", 403);
  }

  const current_plan = getOrganizationCurrentPlan(org_id);
  const resolved = await Promise.all(
    FEATURE_KEYS.map((feature_key) => resolveFeatureAccess({ org_id, feature_key }))
  );
  const effective_feature_count = resolved.filter((item) => item.enabled).length;

  return ok(schema_version, {
    org_id,
    role: membership_for_org.role,
    scope_type: membership_for_org.scope_type,
    plan_code: current_plan.plan_code,
    plan_label: current_plan.plan_label,
    addons: current_plan.addons,
    effective_feature_count
  });
}

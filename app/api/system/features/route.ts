import { fail, get_access_context, ok } from "../../hr/_lib";
import {
  FEATURE_KEYS,
  getOrganizationFeatureAuditMetadata,
  getRequiredAddon,
  isAddonFeature,
  resolveFeatureAccess
} from "../../../lib/featureGating";

const ALLOWED_ROLES = new Set(["owner", "super_admin", "admin"]);

export async function GET(request: Request) {
  const schema_version = "system.feature.list.v1";
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
    return fail(schema_version, "SCOPE_FORBIDDEN", "System features are not accessible", 403);
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

  const { data: override_audit_map, error: override_audit_error } = await getOrganizationFeatureAuditMetadata({
    org_id,
    feature_keys: FEATURE_KEYS
  });
  if (override_audit_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch feature audit metadata", 500);
  }

  const items = await Promise.all(
    FEATURE_KEYS.map(async (feature_key) => {
      const resolved = await resolveFeatureAccess({ org_id, feature_key });
      const audit_meta = override_audit_map.get(feature_key);
      return {
        feature_key,
        enabled: resolved.enabled,
        source: resolved.source,
        is_addon: isAddonFeature(feature_key),
        required_addon: getRequiredAddon(feature_key),
        reason: audit_meta?.reason ?? null,
        updated_at: audit_meta?.updated_at ?? null,
        updated_by_display: audit_meta?.updated_by_display ?? null
      };
    })
  );

  return ok(schema_version, {
    org_id,
    role: membership_for_org.role,
    scope_type: membership_for_org.scope_type,
    items
  });
}

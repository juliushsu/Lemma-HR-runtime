import { fail, get_access_context, ok } from "../../../hr/_lib";
import { isFeatureKey, resolveFeatureAccess, upsertOrganizationFeatureOverride } from "../../../../lib/featureGating";

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ feature_key: string }> }
) {
  const schema_version = "system.feature.update.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const { feature_key } = await params;
  if (!isFeatureKey(feature_key)) {
    return fail(schema_version, "INVALID_FEATURE_KEY", "Feature key is not supported", 400);
  }

  const url = new URL(request.url);
  const requested_org_id = url.searchParams.get("org_id");
  const memberships = ctx.memberships ?? [];

  const owner_memberships = memberships.filter((m) => m.role === "owner");
  if (owner_memberships.length === 0) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Feature override is owner-only", 403);
  }

  const selected_org_id = ctx.current_context?.org_id ?? null;
  if (selected_org_id && requested_org_id && requested_org_id !== selected_org_id) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Requested org does not match selected context", 403);
  }

  const org_id = requested_org_id ?? selected_org_id ?? null;
  if (!org_id) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Selected context is not available", 403);
  }

  const owner_membership_for_org = owner_memberships.find((m) => m.org_id === org_id);
  if (!owner_membership_for_org) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Requested org is not writable by owner", 403);
  }

  const body = (await request.json()) as { enabled?: unknown; reason?: unknown };
  if (typeof body.enabled !== "boolean") {
    return fail(schema_version, "INVALID_REQUEST", "enabled must be boolean", 400);
  }
  if (body.reason !== undefined && body.reason !== null && typeof body.reason !== "string") {
    return fail(schema_version, "INVALID_REQUEST", "reason must be string or null", 400);
  }

  const reason =
    typeof body.reason === "string"
      ? body.reason.trim().slice(0, 500) || null
      : body.reason === null
        ? null
        : null;

  const { data: override, error: write_error } = await upsertOrganizationFeatureOverride({
    org_id,
    feature_key,
    enabled: body.enabled,
    reason,
    actor_user_id: ctx.user_id
  });

  if (write_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to update feature override", 500);
  }

  const resolved = await resolveFeatureAccess({ org_id, feature_key });
  return ok(schema_version, {
    org_id,
    feature_key,
    enabled: resolved.enabled,
    source: resolved.source,
    override: override
      ? {
          is_enabled: override.is_enabled,
          reason: override.reason,
          updated_at: override.updated_at
        }
      : {
          is_enabled: body.enabled,
          reason,
          updated_at: null
        }
  });
}

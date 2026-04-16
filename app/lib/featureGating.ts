import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export type FeatureAccessSource = "plan" | "override" | "default";

export type FeatureAccessResult = {
  enabled: boolean;
  source: FeatureAccessSource;
};

export type FeatureOverrideAuditMeta = {
  reason: string | null;
  updated_at: string | null;
  updated_by: string | null;
  updated_by_display: string | null;
};

export type PlanCode = "Base" | "Pro" | "Enterprise";

export type OrganizationCurrentPlan = {
  plan_code: PlanCode;
  plan_label: string;
  addons: string[];
};

export const FEATURE_KEYS = [
  "attendance.manual_upload.basic",
  "attendance.manual_upload.advanced",
  "attendance.line_checkin",
  "attendance.external_api.standard",
  "attendance.external_api.enterprise"
] as const;

export type FeatureKey = (typeof FEATURE_KEYS)[number];

const PLAN_FEATURES: Record<PlanCode, Set<string>> = {
  Base: new Set([]),
  Pro: new Set([
    "attendance.manual_upload.basic",
    "attendance.line_checkin"
  ]),
  Enterprise: new Set([
    "attendance.manual_upload.basic",
    "attendance.manual_upload.advanced",
    "attendance.line_checkin",
    "attendance.external_api.standard",
    "attendance.external_api.enterprise"
  ])
};

const ADDON_ENTITLEMENT_FEATURES: Record<string, Set<string>> = {
  "attendance.manual_upload.advanced": new Set(["attendance.manual_upload.advanced"]),
  "attendance.external_api.standard": new Set(["attendance.external_api.standard"]),
  "attendance.external_api.enterprise": new Set(["attendance.external_api.enterprise"])
};

const FEATURE_ADDON_REQUIREMENT: Record<FeatureKey, string | null> = {
  "attendance.manual_upload.basic": null,
  "attendance.manual_upload.advanced": "attendance.manual_upload.advanced",
  "attendance.line_checkin": null,
  "attendance.external_api.standard": "attendance.external_api.standard",
  "attendance.external_api.enterprise": "attendance.external_api.enterprise"
};

const ORG_CURRENT_PLAN: Record<string, OrganizationCurrentPlan> = {
  "10000000-0000-0000-0000-000000000001": {
    plan_code: "Enterprise",
    plan_label: "Enterprise",
    addons: []
  },
  "10000000-0000-0000-0000-000000000002": {
    plan_code: "Pro",
    plan_label: "Pro",
    addons: []
  }
};

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

function get_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

export function isFeatureKey(value: string): value is FeatureKey {
  return FEATURE_KEYS.includes(value as FeatureKey);
}

export async function upsertOrganizationFeatureOverride(input: {
  org_id: string;
  feature_key: FeatureKey;
  enabled: boolean;
  reason: string | null;
  actor_user_id: string;
}) {
  const service = get_service_supabase();
  if (!service) {
    return {
      data: null,
      error: { message: "Service role client is not configured" }
    };
  }

  const { data, error } = await service
    .from("organization_features")
    .upsert(
      {
        org_id: input.org_id,
        feature_key: input.feature_key,
        is_enabled: input.enabled,
        reason: input.reason,
        updated_by: input.actor_user_id,
        updated_at: new Date().toISOString()
      },
      { onConflict: "org_id,feature_key" }
    )
    .select("org_id,feature_key,is_enabled,reason,updated_at,updated_by")
    .maybeSingle();

  return { data, error };
}

export async function getOrganizationFeatureAuditMetadata(input: {
  org_id: string;
  feature_keys?: readonly string[];
}) {
  const service = get_service_supabase();
  if (!service) {
    return {
      data: new Map<string, FeatureOverrideAuditMeta>(),
      error: null
    };
  }

  let query = service
    .from("organization_features")
    .select("feature_key,reason,updated_at,updated_by")
    .eq("org_id", input.org_id);

  if (input.feature_keys && input.feature_keys.length > 0) {
    query = query.in("feature_key", input.feature_keys as string[]);
  }

  const { data: overrides, error: overrides_error } = await query;
  if (overrides_error) {
    return {
      data: new Map<string, FeatureOverrideAuditMeta>(),
      error: overrides_error
    };
  }

  const updated_by_user_ids = Array.from(
    new Set((overrides ?? []).map((row) => row.updated_by).filter(Boolean))
  ) as string[];

  const user_display_map = new Map<string, string | null>();
  if (updated_by_user_ids.length > 0) {
    const { data: users, error: users_error } = await service
      .from("users")
      .select("id,display_name,email")
      .in("id", updated_by_user_ids);

    if (users_error) {
      return {
        data: new Map<string, FeatureOverrideAuditMeta>(),
        error: users_error
      };
    }

    for (const user of users ?? []) {
      user_display_map.set(user.id, user.display_name ?? user.email ?? null);
    }
  }

  const map = new Map<string, FeatureOverrideAuditMeta>();
  for (const row of overrides ?? []) {
    const updated_by = row.updated_by ?? null;
    map.set(row.feature_key, {
      reason: row.reason ?? null,
      updated_at: row.updated_at ?? null,
      updated_by,
      updated_by_display: updated_by ? user_display_map.get(updated_by) ?? null : null
    });
  }

  return { data: map, error: null };
}

export function getOrganizationCurrentPlan(org_id: string): OrganizationCurrentPlan {
  return (
    ORG_CURRENT_PLAN[org_id] ?? {
      plan_code: "Base",
      plan_label: "Base",
      addons: []
    }
  );
}

export function getRequiredAddon(feature_key: FeatureKey): string | null {
  return FEATURE_ADDON_REQUIREMENT[feature_key] ?? null;
}

export function isAddonFeature(feature_key: FeatureKey): boolean {
  return getRequiredAddon(feature_key) !== null;
}

function hasOrganizationCurrentPlan(org_id: string) {
  return Boolean(ORG_CURRENT_PLAN[org_id]);
}

function resolvePlanEntitledFeatures(org_id: string): Set<string> | null {
  if (!hasOrganizationCurrentPlan(org_id)) return null;
  const current = getOrganizationCurrentPlan(org_id);
  const plan_features = PLAN_FEATURES[current.plan_code] ?? new Set<string>();
  const result = new Set(plan_features);

  for (const addon of current.addons) {
    const addon_features = ADDON_ENTITLEMENT_FEATURES[addon];
    if (!addon_features) continue;
    for (const feature_key of addon_features) result.add(feature_key);
  }

  return result;
}

export async function resolveFeatureAccess(input: {
  org_id: string;
  feature_key: string;
}): Promise<FeatureAccessResult> {
  const service = get_service_supabase();
  if (service) {
    const { data: override } = await service
      .from("organization_features")
      .select("is_enabled")
      .eq("org_id", input.org_id)
      .eq("feature_key", input.feature_key)
      .maybeSingle();

    if (override && typeof override.is_enabled === "boolean") {
      return {
        enabled: override.is_enabled,
        source: "override"
      };
    }
  }

  const plan_entitled = resolvePlanEntitledFeatures(input.org_id);
  if (plan_entitled) {
    return {
      enabled: plan_entitled.has(input.feature_key),
      source: "plan"
    };
  }

  return {
    enabled: false,
    source: "default"
  };
}

export function featureNotEnabledResponse(feature_key: string, status = 403) {
  return NextResponse.json(
    {
      error: {
        code: "FEATURE_NOT_ENABLED",
        feature_key
      }
    },
    { status }
  );
}

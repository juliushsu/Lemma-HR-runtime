import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.SUPABASE_ANON_KEY ?? "";

export const SELECTED_CONTEXT_COOKIE = "lemma_selected_membership_id";
export const SELECTED_CONTEXT_COOKIE_MAX_AGE = 60 * 60 * 24 * 30;
export const PREVIEW_CONTEXT_HEADER = "x-preview-context";

const WRITE_ROLES = new Set(["owner", "super_admin", "org_super_admin", "admin"]);

function parseEnvFlag(value: string | undefined): boolean {
  const normalized = String(value ?? "").trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on";
}

export type MembershipRow = {
  id: string;
  user_id: string;
  org_id: string;
  company_id: string | null;
  branch_id: string | null;
  role: string;
  scope_type: string;
  environment_type: "production" | "demo" | "sandbox" | "seed";
  is_demo: boolean;
  created_at?: string;
};

export type ContextOrg = {
  id: string;
  slug?: string | null;
  name: string;
  locale_default?: string | null;
  environment_type?: string | null;
  is_demo?: boolean | null;
  access_mode?: string | null;
};

export type ContextCompany = {
  id: string;
  org_id: string;
  name: string;
  locale_default?: string | null;
  environment_type?: string | null;
};

export type CurrentContext = {
  membership_id: string;
  org_id: string;
  org_slug: string | null;
  org_name: string | null;
  company_id: string | null;
  company_name: string | null;
  role: string;
  scope_type: string;
  environment_type: string;
  access_mode: "read_only_demo" | "sandbox_write" | "production_live";
  writable: boolean;
  is_default: boolean;
};

export type SelectedContextBundle = {
  supabase: any;
  user_id: string;
  user: {
    id: string;
    email: string | null;
    display_name: string | null;
    locale_preference?: string | null;
    timezone?: string | null;
    currency?: string | null;
    environment_type?: string | null;
  } | null;
  memberships: MembershipRow[];
  available_contexts: CurrentContext[];
  current_context: CurrentContext | null;
  current_membership: MembershipRow | null;
  current_org: ContextOrg | null;
  current_company: ContextCompany | null;
  locale: string;
  environment_type: string;
  preview_override_active: boolean;
};

export function isStagingRuntime() {
  const values = [process.env.APP_ENV, process.env.NEXT_PUBLIC_APP_ENV, process.env.DEPLOY_TARGET]
    .filter(Boolean)
    .map((v) => String(v).toLowerCase());

  return values.some((v) => v === "staging" || v.includes("staging"));
}

export function get_selected_membership_cookie(request: Request) {
  const cookieHeader = request.headers.get("cookie") ?? "";
  for (const chunk of cookieHeader.split(";")) {
    const [rawName, ...rest] = chunk.split("=");
    if (!rawName || rest.length === 0) continue;
    const name = rawName.trim();
    if (name !== SELECTED_CONTEXT_COOKIE) continue;
    const value = rest.join("=").trim();
    if (!value) return null;
    try {
      return decodeURIComponent(value);
    } catch {
      return value;
    }
  }
  return null;
}

export function get_preview_origin_allowed(request: Request) {
  const allowedOrigin = String(process.env.ALLOW_PREVIEW_ORIGIN ?? "").trim();
  if (!allowedOrigin) return false;
  return (request.headers.get("origin") ?? "").trim() === allowedOrigin;
}

export function get_preview_context_override(request: Request) {
  const headerValue = request.headers.get(PREVIEW_CONTEXT_HEADER)?.trim() ?? "";
  const queryValue = new URL(request.url).searchParams.get("_preview_ctx")?.trim() ?? "";
  const requested = headerValue || queryValue;
  if (!requested) return null;

  const previewEnabled = parseEnvFlag(process.env.ALLOW_PREVIEW_CONTEXT_OVERRIDE);
  if (!previewEnabled && !get_preview_origin_allowed(request)) return null;
  return requested;
}

export function is_preview_force_read_only() {
  const configured = process.env.PREVIEW_FORCE_READ_ONLY;
  if (configured === undefined) return true;
  return parseEnvFlag(configured);
}

export function resolve_selected_membership_id<T extends { id: string }>(request: Request, memberships: T[]) {
  const previewMembershipId = get_preview_context_override(request);
  const previewMatch = previewMembershipId
    ? memberships.find((membership) => membership.id === previewMembershipId) ?? null
    : null;
  if (previewMatch) {
    return {
      selected_membership_id: previewMatch.id,
      preview_override_active: true
    };
  }

  const cookieMembershipId = isStagingRuntime() ? get_selected_membership_cookie(request) : null;
  return {
    selected_membership_id: cookieMembershipId,
    preview_override_active: false
  };
}

export function derive_access_mode(
  membership: Pick<MembershipRow, "environment_type" | "is_demo">,
  org: Pick<ContextOrg, "is_demo" | "access_mode"> | null
): "read_only_demo" | "sandbox_write" | "production_live" {
  const explicit = org?.access_mode;
  if (explicit === "read_only_demo" || explicit === "sandbox_write" || explicit === "production_live") {
    return explicit;
  }

  if (membership.is_demo || org?.is_demo === true || membership.environment_type === "demo") {
    return "read_only_demo";
  }

  if (membership.environment_type === "sandbox" || membership.environment_type === "seed") {
    return "sandbox_write";
  }

  return "production_live";
}

export function can_write_selected_context(
  membership: Pick<MembershipRow, "role">,
  access_mode: ReturnType<typeof derive_access_mode>,
  userEmail: string | null | undefined
) {
  if (access_mode === "read_only_demo") return false;
  if (isStagingRuntime() && (userEmail ?? "").toLowerCase() === "team@lemmaofficial.com") return false;
  return WRITE_ROLES.has(membership.role);
}

function pick_bootstrap_membership(memberships: MembershipRow[]) {
  if (memberships.length === 0) return null;

  const sandbox = memberships.find((membership) => membership.environment_type === "sandbox" && membership.is_demo === false);
  if (sandbox) return sandbox;

  const demo = memberships.find((membership) => membership.environment_type === "demo" || membership.is_demo === true);
  if (demo) return demo;

  return memberships[0];
}

export async function load_selected_context_bundle(request: Request): Promise<SelectedContextBundle | null> {
  const authHeader = request.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !token) return null;

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });

  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) return null;

  const user_id = authData.user.id;

  const [{ data: user }, { data: memberships }] = await Promise.all([
    supabase
      .from("users")
      .select("id,email,display_name,locale_preference,timezone,currency,environment_type")
      .eq("id", user_id)
      .maybeSingle(),
    supabase
      .from("memberships")
      .select("id,user_id,org_id,company_id,branch_id,role,scope_type,environment_type,is_demo,created_at")
      .eq("user_id", user_id)
      .order("created_at", { ascending: true })
  ]);

  const membershipRows = (memberships ?? []) as MembershipRow[];
  if (membershipRows.length === 0) return null;

  const orgIds = Array.from(new Set(membershipRows.map((membership) => membership.org_id)));
  const companyIds = Array.from(new Set(membershipRows.map((membership) => membership.company_id).filter(Boolean))) as string[];

  const [{ data: orgs }, { data: companies }] = await Promise.all([
    supabase
      .from("organizations")
      .select("id,slug,name,locale_default,environment_type,is_demo")
      .in("id", orgIds),
    companyIds.length > 0
      ? supabase
          .from("companies")
          .select("id,org_id,name,locale_default,environment_type")
          .in("id", companyIds)
      : Promise.resolve({ data: [] as ContextCompany[] })
  ]);

  const orgById = new Map<string, ContextOrg>((orgs ?? []).map((org: ContextOrg) => [org.id, org] as [string, ContextOrg]));
  const companyById = new Map<string, ContextCompany>(
    (companies ?? []).map((company: ContextCompany) => [company.id, company] as [string, ContextCompany])
  );

  const { selected_membership_id: preferredMembershipId, preview_override_active } = resolve_selected_membership_id(
    request,
    membershipRows
  );
  const selectedMembership =
    membershipRows.find((membership) => membership.id === preferredMembershipId) ?? pick_bootstrap_membership(membershipRows);

  const available_contexts = membershipRows.map((membership) => {
    const org = orgById.get(membership.org_id) ?? null;
    const company = membership.company_id ? companyById.get(membership.company_id) ?? null : null;
    const access_mode = derive_access_mode(membership, org);

    return {
      membership_id: membership.id,
      org_id: membership.org_id,
      org_slug: org?.slug ?? null,
      org_name: org?.name ?? null,
      company_id: membership.company_id,
      company_name: company?.name ?? null,
      role: membership.role,
      scope_type: membership.scope_type,
      environment_type: membership.environment_type,
      access_mode,
      writable:
        preview_override_active && is_preview_force_read_only()
          ? false
          : can_write_selected_context(membership, access_mode, user?.email),
      is_default: membership.id === selectedMembership?.id
    } satisfies CurrentContext;
  });

  const current_context = available_contexts.find((context) => context.membership_id === selectedMembership?.id) ?? null;
  const current_org = current_context ? orgById.get(current_context.org_id) ?? null : null;
  const current_company =
    current_context?.company_id ? companyById.get(current_context.company_id) ?? null : null;

  const locale =
    user?.locale_preference ??
    current_company?.locale_default ??
    current_org?.locale_default ??
    "en";

  return {
    supabase,
    user_id,
    user: user ?? null,
    memberships: membershipRows,
    available_contexts,
    current_context,
    current_membership: selectedMembership ?? null,
    current_org,
    current_company,
    locale,
    environment_type: current_context?.environment_type ?? user?.environment_type ?? "production",
    preview_override_active
  };
}

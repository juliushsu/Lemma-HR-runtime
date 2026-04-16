import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import {
  CurrentContext,
  isStagingRuntime,
  is_preview_force_read_only,
  resolve_selected_membership_id
} from "../_selected_context";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.SUPABASE_ANON_KEY ?? "";

type Membership = {
  id: string;
  org_id: string;
  company_id: string | null;
  branch_id: string | null;
  role: string;
  scope_type: string;
  environment_type: "production" | "demo" | "sandbox" | "seed";
  is_demo: boolean;
};

export type LegalScope = {
  org_id: string;
  company_id: string;
  branch_id: string | null;
  environment_type: "production" | "demo" | "sandbox" | "seed";
  is_demo: boolean;
};

export type AccessContext = {
  supabase: any;
  user_id: string;
  user_email: string | null;
  memberships: Membership[];
  current_context: CurrentContext | null;
  preview_override_active: boolean;
};

export function ok(schema_version: string, data: Record<string, unknown>, status = 200) {
  return NextResponse.json(
    {
      schema_version,
      data,
      meta: {
        request_id: randomUUID(),
        timestamp: new Date().toISOString()
      },
      error: null
    },
    { status }
  );
}

export function fail(schema_version: string, code: string, message: string, status = 400) {
  return NextResponse.json(
    {
      schema_version,
      data: {},
      meta: {
        request_id: randomUUID(),
        timestamp: new Date().toISOString()
      },
      error: { code, message }
    },
    { status }
  );
}

export async function get_access_context(request: Request): Promise<AccessContext | null> {
  const authHeader = request.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !token) return null;

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });

  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) return null;

  const [{ data: memberships }, { data: user }] = await Promise.all([
    supabase
      .from("memberships")
      .select("id,org_id,company_id,branch_id,role,scope_type,environment_type,is_demo")
      .eq("user_id", authData.user.id),
    supabase.from("users").select("email").eq("id", authData.user.id).maybeSingle()
  ]);

  if (!memberships || memberships.length === 0) return null;
  return {
    supabase,
    user_id: authData.user.id,
    user_email: user?.email ?? null,
    memberships: memberships as Membership[],
    ...resolve_current_context(memberships as Membership[], request, user?.email ?? null)
  };
}

export function fail_preview_read_only(schema_version: string) {
  return fail(schema_version, "PREVIEW_READ_ONLY", "Preview context override is read-only", 403);
}

export function reject_preview_override_write(schema_version: string, ctx: AccessContext) {
  if (ctx.preview_override_active && is_preview_force_read_only()) {
    return fail_preview_read_only(schema_version);
  }
  return null;
}

export function resolve_scope(request: Request, ctx: AccessContext, body?: Record<string, unknown>): LegalScope | null {
  const url = new URL(request.url);
  const current = ctx.current_context;
  const requested_org_id = (body?.org_id as string | undefined) ?? url.searchParams.get("org_id");
  const requested_company_id = (body?.company_id as string | undefined) ?? url.searchParams.get("company_id");
  const requested_environment_type =
    ((body?.environment_type as LegalScope["environment_type"] | undefined) ??
      (url.searchParams.get("environment_type") as LegalScope["environment_type"] | null)) ??
    null;
  const requested_branch_id = ((body?.branch_id as string | null | undefined) ?? url.searchParams.get("branch_id") ?? null);

  if (current?.org_id && requested_org_id && requested_org_id !== current.org_id) return null;
  if (current?.company_id && requested_company_id && requested_company_id !== current.company_id) return null;
  if (current?.environment_type && requested_environment_type && requested_environment_type !== current.environment_type) return null;

  const org_id = requested_org_id ?? current?.org_id ?? ctx.memberships[0].org_id;
  const company_id =
    requested_company_id ??
    current?.company_id ??
    ctx.memberships.find((m) => m.org_id === org_id && m.company_id)?.company_id ??
    null;
  const branch_id =
    requested_branch_id ??
    null;
  const environment_type =
    (requested_environment_type ??
      current?.environment_type ??
      ctx.memberships.find((m) => m.org_id === org_id && m.company_id === company_id)?.environment_type ??
      "production") as LegalScope["environment_type"];

  if (!org_id || !company_id) return null;

  const matched = ctx.memberships.find(
    (m) =>
      m.org_id === org_id &&
      (m.company_id === null || m.company_id === company_id) &&
      m.environment_type === environment_type
  );
  if (!matched) return null;

  return {
    org_id,
    company_id,
    branch_id,
    environment_type,
    is_demo: matched.is_demo
  };
}

function resolve_current_context(memberships: Membership[], request: Request, user_email: string | null) {
  const { selected_membership_id, preview_override_active } = resolve_selected_membership_id(request, memberships);
  const selected =
    memberships.find((membership) => membership.id === selected_membership_id) ??
    memberships.find((membership) => membership.environment_type === "sandbox" && membership.is_demo === false) ??
    memberships.find((membership) => membership.environment_type === "demo" || membership.is_demo === true) ??
    memberships[0] ??
    null;

  if (!selected) {
    return {
      current_context: null,
      preview_override_active
    };
  }

  const access_mode: CurrentContext["access_mode"] =
    selected.is_demo || selected.environment_type === "demo"
      ? "read_only_demo"
      : selected.environment_type === "sandbox" || selected.environment_type === "seed"
        ? "sandbox_write"
        : "production_live";

  return {
    current_context: {
      membership_id: selected.id,
      org_id: selected.org_id,
      org_slug: null,
      org_name: null,
      company_id: selected.company_id,
      company_name: null,
      role: selected.role,
      scope_type: selected.scope_type,
      environment_type: selected.environment_type,
      access_mode,
      writable:
        !(preview_override_active && is_preview_force_read_only()) &&
        access_mode !== "read_only_demo" &&
        (!isStagingRuntime() || (user_email ?? "").toLowerCase() !== "team@lemmaofficial.com"),
      is_default: true
    },
    preview_override_active
  };
}

export function scopedQuery<T extends { eq: (column: string, value: unknown) => T }>(query: T, scope: LegalScope) {
  let q = query
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type);
  if (scope.branch_id) q = q.eq("branch_id", scope.branch_id);
  return q;
}

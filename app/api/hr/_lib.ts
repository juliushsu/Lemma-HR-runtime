import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";
import {
  CurrentContext,
  isStagingRuntime,
  is_preview_force_read_only,
  resolve_selected_membership_id
} from "../_selected_context";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.SUPABASE_ANON_KEY ?? "";

export type Membership = {
  id: string;
  org_id: string;
  company_id: string | null;
  branch_id: string | null;
  role: string;
  scope_type: string;
  environment_type: string;
  is_demo: boolean;
};

export type Scope = {
  org_id: string;
  company_id: string;
  branch_id: string | null;
  environment_type: string;
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

const READ_ROLES = new Set(["owner", "super_admin", "org_super_admin", "admin", "manager", "operator", "viewer"]);
const WRITE_ROLES = new Set(["owner", "super_admin", "org_super_admin", "admin"]);

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

export function fail(
  schema_version: string,
  code: string,
  message: string,
  status = 400,
  details: Record<string, unknown> | null = null
) {
  return NextResponse.json(
    {
      schema_version,
      data: {},
      meta: {
        request_id: randomUUID(),
        timestamp: new Date().toISOString()
      },
      error: {
        code,
        message,
        details
      }
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

  const user_id = authData.user.id;
  const [{ data: memberships }, { data: user }] = await Promise.all([
    supabase
    .from("memberships")
    .select("id,org_id,company_id,branch_id,role,scope_type,environment_type,is_demo")
    .eq("user_id", user_id),
    supabase.from("users").select("email").eq("id", user_id).maybeSingle()
  ]);

  if (!memberships || memberships.length === 0) return null;
  const resolved = resolve_current_context(memberships as Membership[], request, user?.email ?? null);
  return {
    supabase,
    user_id,
    user_email: user?.email ?? null,
    memberships: memberships as Membership[],
    current_context: resolved.current_context,
    preview_override_active: resolved.preview_override_active
  };
}

export function resolve_scope(ctx: AccessContext, request: Request): Scope | null {
  const url = new URL(request.url);
  const current = ctx.current_context;
  const requested_org_id = url.searchParams.get("org_id");
  const requested_company_id = url.searchParams.get("company_id");
  const requested_environment_type = url.searchParams.get("environment_type");
  const requested_branch_id = normalize_branch_id(url.searchParams.get("branch_id"));

  if (current?.org_id && requested_org_id && requested_org_id !== current.org_id) return null;
  if (current?.company_id && requested_company_id && requested_company_id !== current.company_id) return null;
  if (current?.environment_type && requested_environment_type && requested_environment_type !== current.environment_type) return null;

  const org_id = requested_org_id ?? current?.org_id ?? ctx.memberships[0]?.org_id ?? null;
  const company_id =
    requested_company_id ??
    current?.company_id ??
    ctx.memberships.find((m) => m.org_id === org_id && m.company_id)?.company_id ??
    null;
  const branch_id = requested_branch_id ?? ctx.memberships.find((m) => m.org_id === org_id && m.company_id === company_id)?.branch_id ?? null;
  const environment_type =
    requested_environment_type ??
    current?.environment_type ??
    ctx.memberships.find((m) => m.org_id === org_id && m.company_id === company_id)?.environment_type ??
    "production";

  if (!org_id || !company_id) return null;

  const matched = ctx.memberships.filter(
    (m) =>
      m.org_id === org_id &&
      (m.company_id === null || m.company_id === company_id) &&
      m.environment_type === environment_type
  );
  if (matched.length === 0) return null;

  const hasBranchScope = matched.some(
    (m) =>
      m.scope_type === "org" ||
      m.scope_type === "company" ||
      (m.scope_type === "branch" && (!branch_id || m.branch_id === branch_id))
  );
  if (!hasBranchScope) return null;

  return {
    org_id,
    company_id,
    branch_id: branch_id ?? null,
    environment_type,
    is_demo: matched[0].is_demo
  };
}

function normalize_branch_id(value: string | null): string | null {
  if (!value) return null;
  const v = value.trim();
  if (!v) return null;
  if (v === "null" || v === "undefined") return null;
  if (v === "00000000-0000-0000-0000-000000000000") return null;
  return v;
}

export function can_read(ctx: AccessContext, scope: Scope) {
  return ctx.memberships.some((m) => role_scope_match(m, scope) && READ_ROLES.has(m.role));
}

export function can_write(ctx: AccessContext, scope: Scope) {
  if (ctx.preview_override_active && is_preview_force_read_only()) return false;
  if (ctx.current_context?.access_mode === "read_only_demo") return false;
  if (isStagingRuntime() && (ctx.user_email ?? "").toLowerCase() === "team@lemmaofficial.com") return false;
  return ctx.memberships.some((m) => role_scope_match(m, scope) && WRITE_ROLES.has(m.role));
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

function role_scope_match(m: Membership, scope: Scope) {
  if (m.org_id !== scope.org_id) return false;
  if (m.environment_type !== scope.environment_type) return false;
  if (m.company_id && m.company_id !== scope.company_id) return false;

  if (m.scope_type === "org") return true;
  if (m.scope_type === "company") return m.company_id === scope.company_id;
  if (m.scope_type === "branch") return m.company_id === scope.company_id && m.branch_id === scope.branch_id;
  if (m.scope_type === "self") return true;
  return false;
}

export function apply_scope<T extends { eq: (column: string, value: unknown) => T }>(
  query: T,
  scope: Scope
) {
  let next = query.eq("org_id", scope.org_id).eq("company_id", scope.company_id).eq("environment_type", scope.environment_type);
  if (scope.branch_id) next = next.eq("branch_id", scope.branch_id);
  return next;
}

export function parse_pagination(request: Request) {
  const url = new URL(request.url);
  const page = Math.max(1, Number(url.searchParams.get("page") ?? "1"));
  const page_size = Math.min(100, Math.max(1, Number(url.searchParams.get("page_size") ?? "20")));
  return { page, page_size, from: (page - 1) * page_size, to: page * page_size - 1 };
}

export function get_display_name(employee: {
  display_name: string | null;
  preferred_name: string | null;
  legal_name: string | null;
}) {
  return employee.display_name ?? employee.preferred_name ?? employee.legal_name;
}

export function local_date_in_timezone(iso: string, timezone: string) {
  const dt = new Date(iso);
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).format(dt);
}

export function local_minutes_in_timezone(iso: string, timezone: string) {
  const dt = new Date(iso);
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).formatToParts(dt);
  const hh = Number(parts.find((p) => p.type === "hour")?.value ?? "0");
  const mm = Number(parts.find((p) => p.type === "minute")?.value ?? "0");
  return hh * 60 + mm;
}

export function parse_hhmm_to_minutes(value: string | null): number | null {
  if (!value) return null;
  const [hh, mm] = value.split(":");
  if (hh === undefined || mm === undefined) return null;
  return Number(hh) * 60 + Number(mm);
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
        (!isStagingRuntime() || (user_email ?? "").toLowerCase() !== "team@lemmaofficial.com") &&
        WRITE_ROLES.has(selected.role),
      is_default: true
    },
    preview_override_active
  };
}

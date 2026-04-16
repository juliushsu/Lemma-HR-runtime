import { NextResponse } from "next/server";
import {
  get_access_context,
  resolve_scope,
  can_read,
  can_write,
  type AccessContext,
  type Scope
} from "./hr/_lib";

type EnvelopeError = {
  code: string;
  message: string;
  details?: Record<string, unknown> | null;
};

export function success(data: Record<string, unknown>, status = 200) {
  return NextResponse.json(
    {
      success: true,
      data
    },
    { status }
  );
}

export function failure(
  code: string,
  message: string,
  status = 400,
  details: Record<string, unknown> | null = null
) {
  const error: EnvelopeError = { code, message };
  if (details) error.details = details;
  return NextResponse.json(
    {
      success: false,
      error
    },
    { status }
  );
}

function is_staging_runtime() {
  const values = [process.env.APP_ENV, process.env.NEXT_PUBLIC_APP_ENV, process.env.DEPLOY_TARGET]
    .filter(Boolean)
    .map((v) => String(v).toLowerCase());
  return values.some((v) => v === "staging" || v.includes("staging"));
}

export function ensure_staging_only() {
  if (is_staging_runtime()) return null;
  return failure("STAGING_ONLY", "This endpoint is available in staging only", 403);
}

function resolve_scope_from_body(ctx: AccessContext, body: Record<string, unknown> | null): Scope | null {
  if (!body) return null;

  const current = ctx.current_context;
  const requested_org_id = typeof body.org_id === "string" && body.org_id.trim() ? body.org_id.trim() : null;
  const requested_company_id = typeof body.company_id === "string" && body.company_id.trim() ? body.company_id.trim() : null;
  const requested_environment_type =
    typeof body.environment_type === "string" && body.environment_type.trim() ? body.environment_type.trim() : null;
  const requested_branch_id =
    typeof body.branch_id === "string" && body.branch_id.trim() && body.branch_id !== "null" ? body.branch_id : null;

  if (current?.org_id && requested_org_id && requested_org_id !== current.org_id) return null;
  if (current?.company_id && requested_company_id && requested_company_id !== current.company_id) return null;
  if (current?.environment_type && requested_environment_type && requested_environment_type !== current.environment_type) {
    return null;
  }

  const org_id = requested_org_id ?? current?.org_id ?? ctx.memberships[0]?.org_id;
  if (!org_id) return null;

  const company_id =
    requested_company_id ??
    current?.company_id ??
    ctx.memberships.find((m) => m.org_id === org_id && m.company_id)?.company_id ??
    null;
  if (!company_id) return null;

  const environment_type =
    requested_environment_type ??
    current?.environment_type ??
    ctx.memberships.find((m) => m.org_id === org_id && m.company_id === company_id)?.environment_type ??
    "production";

  const branch_id = requested_branch_id ?? ctx.memberships.find((m) => m.org_id === org_id && m.company_id === company_id)?.branch_id ?? null;

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
    branch_id,
    environment_type,
    is_demo: matched[0].is_demo
  };
}

export async function get_scoped_context(
  request: Request,
  options: { write: boolean; body?: Record<string, unknown> | null } = { write: false }
) {
  const stagingError = ensure_staging_only();
  if (stagingError) return { response: stagingError };

  const ctx = await get_access_context(request);
  if (!ctx) return { response: failure("UNAUTHORIZED", "Unauthorized", 401) };

  const scope = resolve_scope(ctx, request) ?? resolve_scope_from_body(ctx, options.body ?? null);
  if (!scope) return { response: failure("SCOPE_FORBIDDEN", "Scope is not accessible", 403) };

  const permitted = options.write ? can_write(ctx, scope) : can_read(ctx, scope);
  if (!permitted) {
    return { response: failure("SCOPE_FORBIDDEN", options.write ? "Scope is not writable" : "Scope is not readable", 403) };
  }

  return { ctx, scope, response: null as NextResponse | null };
}

export function parse_json_body(raw: string | null) {
  if (!raw) return {};
  try {
    return JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function to_bool(input: unknown): boolean | null {
  if (typeof input === "boolean") return input;
  if (typeof input === "string") {
    const normalized = input.trim().toLowerCase();
    if (normalized === "true") return true;
    if (normalized === "false") return false;
  }
  return null;
}

export function to_number(input: unknown): number | null {
  if (typeof input === "number" && Number.isFinite(input)) return input;
  if (typeof input === "string" && input.trim()) {
    const parsed = Number(input);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

export function haversine_distance_m(
  latitude_1: number,
  longitude_1: number,
  latitude_2: number,
  longitude_2: number
) {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const R = 6371000;
  const dLat = toRad(latitude_2 - latitude_1);
  const dLon = toRad(longitude_2 - longitude_1);
  const lat1 = toRad(latitude_1);
  const lat2 = toRad(latitude_2);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

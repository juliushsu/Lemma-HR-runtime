import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.SUPABASE_ANON_KEY ?? "";

function isStagingRuntime(): boolean {
  const values = [
    process.env.APP_ENV,
    process.env.NEXT_PUBLIC_APP_ENV,
    process.env.DEPLOY_TARGET
  ]
    .filter(Boolean)
    .map((v) => String(v).toLowerCase());
  return values.some((v) => v === "staging" || v.includes("staging"));
}

function getAllowedOrigins(): string[] {
  const configured = process.env.CORS_ALLOWED_ORIGINS ?? "";
  return configured
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function resolveAllowOrigin(request: NextRequest): string | null {
  const origin = request.headers.get("origin");
  const allowList = getAllowedOrigins();
  if (!origin) return null;
  if (allowList.length === 0) return origin;
  return allowList.includes(origin) ? origin : null;
}

function applyCors(request: NextRequest, response: NextResponse): NextResponse {
  const allowOrigin = resolveAllowOrigin(request);
  if (!allowOrigin) return response;

  response.headers.set("Access-Control-Allow-Origin", allowOrigin);
  response.headers.set("Access-Control-Allow-Credentials", "true");
  response.headers.set("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS");
  response.headers.set("Access-Control-Allow-Headers", "authorization,content-type,x-preview-context");
  response.headers.set("Access-Control-Expose-Headers", "x-request-id");
  response.headers.set("Vary", "Origin");

  return response;
}

function rejectJson(status: number, code: string, message: string) {
  return NextResponse.json(
    {
      schema_version: "security.beta_lock.v1",
      data: {},
      meta: {
        timestamp: new Date().toISOString()
      },
      error: {
        code,
        message
      }
    },
    { status }
  );
}

async function enforceBetaLock(request: NextRequest): Promise<NextResponse | null> {
  if (!isStagingRuntime()) return null;

  // Intake endpoint is intentionally public in staging for marketing-form testing.
  if (request.nextUrl.pathname === "/api/intake/request" && request.method === "POST") {
    return null;
  }

  const authHeader = request.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (!token) return rejectJson(401, "UNAUTHORIZED", "Missing bearer token");
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return rejectJson(500, "SECURITY_CONFIG_MISSING", "Supabase runtime config is missing");
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });

  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    return rejectJson(401, "UNAUTHORIZED", "Invalid token");
  }

  const userId = authData.user.id;
  const [{ data: testFlag }, { data: internalFlag }] = await Promise.all([
    supabase.rpc("is_test_user", { p_user_id: userId }),
    supabase.rpc("is_internal_user", { p_user_id: userId })
  ]);
  const { data: portalFlag } = await supabase.rpc("is_portal_user", { p_user_id: userId });
  const { data: userProfile } = await supabase
    .from("users")
    .select("security_role")
    .eq("id", userId)
    .maybeSingle();

  const isTestUser = testFlag === true;
  const isInternalUser = internalFlag === true;
  const isPortalUser = portalFlag === true;
  const isOrgSuperAdmin = userProfile?.security_role === "org_super_admin";
  if (!isTestUser && !isInternalUser && !isPortalUser && !isOrgSuperAdmin) {
    return rejectJson(403, "BETA_LOCK_FORBIDDEN", "Access restricted to staging test/internal/portal users");
  }

  // Best-effort access logging. Do not block request path on log failure.
  await supabase.rpc("log_api_access", {
    p_endpoint: request.nextUrl.pathname,
    p_is_test_user: isTestUser
  });

  return null;
}

export async function middleware(request: NextRequest) {
  const allowOrigin = resolveAllowOrigin(request);
  if (request.method === "OPTIONS" && !allowOrigin) {
    return new Response(null, { status: 403 });
  }

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": allowOrigin ?? "",
        "Access-Control-Allow-Credentials": "true",
        "Access-Control-Allow-Headers": "authorization,content-type,x-preview-context",
        "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
        "Access-Control-Expose-Headers": "x-request-id",
        Vary: "Origin"
      }
    });
  }

  const betaLockResult = await enforceBetaLock(request);
  if (betaLockResult) return applyCors(request, betaLockResult);

  return applyCors(request, NextResponse.next());
}

export const config = {
  matcher: ["/api/:path*"]
};

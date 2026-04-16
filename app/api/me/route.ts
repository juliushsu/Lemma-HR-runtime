import { NextResponse } from "next/server";
import { load_selected_context_bundle, isStagingRuntime } from "../_selected_context";

function getAllowedOrigins(): string[] {
  return String(process.env.CORS_ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

function resolveAllowOrigin(request: Request): string | null {
  const origin = request.headers.get("origin");
  const allowList = getAllowedOrigins();
  if (!origin) return null;
  if (allowList.length === 0) return origin;
  return allowList.includes(origin) ? origin : null;
}

function addDebugHeaders(
  response: NextResponse,
  payload: {
    auth_user_id?: string | null;
    membership_role?: string | null;
    org_id?: string | null;
    company_id?: string | null;
    environment_type?: string | null;
    access_mode?: string | null;
  }
) {
  if (!isStagingRuntime()) return response;

  response.headers.set("x-debug-auth-user-id", payload.auth_user_id ?? "");
  response.headers.set("x-debug-membership-role", payload.membership_role ?? "");
  response.headers.set("x-debug-org-id", payload.org_id ?? "");
  response.headers.set("x-debug-company-id", payload.company_id ?? "");
  response.headers.set("x-debug-environment-type", payload.environment_type ?? "");
  response.headers.set("x-debug-access-mode", payload.access_mode ?? "");
  return response;
}

export async function OPTIONS(request: Request) {
  const allowOrigin = resolveAllowOrigin(request);
  if (!allowOrigin) {
    return new Response(null, { status: 403 });
  }

  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": allowOrigin,
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Headers": "authorization,content-type,x-preview-context",
      "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
      "Access-Control-Expose-Headers": "x-request-id",
      Vary: "Origin"
    }
  });
}

export async function GET(request: Request) {
  try {
    const bundle = await load_selected_context_bundle(request);
    if (!bundle) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const response = NextResponse.json({
      schema_version: isStagingRuntime() ? "auth.me.v2" : "auth.me.v1",
      data: {
        user: bundle.user,
        memberships: bundle.memberships.map((membership) => ({
          id: membership.id,
          user_id: membership.user_id,
          org_id: membership.org_id,
          company_id: membership.company_id,
          branch_id: membership.branch_id,
          role: membership.role,
          scope_type: membership.scope_type,
          environment_type: membership.environment_type,
          is_default: membership.id === bundle.current_membership?.id
        })),
        available_contexts: isStagingRuntime() ? bundle.available_contexts : [],
        current_context: isStagingRuntime() ? bundle.current_context : null,
        current_org: bundle.current_org,
        current_company: bundle.current_company,
        locale: bundle.locale,
        environment_type: bundle.environment_type
      }
    });

    return addDebugHeaders(response, {
      auth_user_id: bundle.user_id,
      membership_role: bundle.current_context?.role ?? null,
      org_id: bundle.current_context?.org_id ?? null,
      company_id: bundle.current_context?.company_id ?? null,
      environment_type: bundle.environment_type,
      access_mode: bundle.current_context?.access_mode ?? null
    });
  } catch (error) {
    console.error("GET /api/me failed", error);
    return NextResponse.json(
      {
        schema_version: isStagingRuntime() ? "auth.me.v2" : "auth.me.v1",
        data: {
          user: null,
          memberships: [],
          available_contexts: [],
          current_context: null,
          current_org: null,
          current_company: null,
          locale: null,
          environment_type: null
        },
        error: {
          code: "INTERNAL_ERROR",
          message: "Failed to resolve current session context"
        }
      },
      { status: 500 }
    );
  }
}

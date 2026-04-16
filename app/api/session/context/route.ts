import { NextResponse } from "next/server";
import {
  SELECTED_CONTEXT_COOKIE,
  SELECTED_CONTEXT_COOKIE_MAX_AGE,
  isStagingRuntime,
  load_selected_context_bundle
} from "../../_selected_context";

const SCHEMA_VERSION = "auth.session.context.v1";

function fail(code: string, message: string, status: number, details: Record<string, unknown> | null = null) {
  return NextResponse.json(
    {
      schema_version: SCHEMA_VERSION,
      data: {
        current_context: null
      },
      meta: {
        request_id: crypto.randomUUID(),
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

export async function OPTIONS() {
  return new Response(null, { status: 204 });
}

export async function POST(request: Request) {
  if (!isStagingRuntime()) {
    return fail("STAGING_ONLY", "Context switching is available in staging only", 403);
  }

  const bundle = await load_selected_context_bundle(request);
  if (!bundle) return fail("UNAUTHORIZED", "Unauthorized", 401);

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return fail("INVALID_REQUEST", "Invalid JSON body", 400);
  }

  const membership_id = typeof body.membership_id === "string" ? body.membership_id.trim() : "";
  if (!membership_id) {
    return fail("INVALID_REQUEST", "membership_id is required", 400);
  }

  const target = bundle.available_contexts.find((context) => context.membership_id === membership_id) ?? null;
  if (!target) {
    return fail("MEMBERSHIP_NOT_FOUND", "The requested membership is not available to the current user.", 404);
  }

  if (target.writable && (bundle.user?.email ?? "").toLowerCase() === "team@lemmaofficial.com") {
    return fail(
      "CONTEXT_SWITCH_FORBIDDEN",
      "The requested workspace cannot be selected in the current rollout stage.",
      403
    );
  }

  const response = NextResponse.json({
    schema_version: SCHEMA_VERSION,
    data: {
      current_context: target
    },
    meta: {
      request_id: crypto.randomUUID(),
      timestamp: new Date().toISOString()
    },
    error: null
  });

  response.cookies.set({
    name: SELECTED_CONTEXT_COOKIE,
    value: membership_id,
    httpOnly: true,
    sameSite: "none",
    secure: true,
    path: "/",
    maxAge: SELECTED_CONTEXT_COOKIE_MAX_AGE
  });

  return response;
}

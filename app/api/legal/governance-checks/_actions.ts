import { createClient } from "@supabase/supabase-js";
import { fail, get_access_context, reject_preview_override_write } from "../_lib";
import { can_write_governance } from "./_lib";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

type ActionContext = {
  response: Response | null;
  ctx: Awaited<ReturnType<typeof get_access_context>>;
  scope: {
    org_id: string;
    company_id: string;
    branch_id: string | null;
    environment_type: string;
    is_demo: boolean;
  } | null;
  service: any;
};

type AcknowledgeResult = {
  response: Response | null;
  data: {
    check_id: string;
    company_decision_status: string;
    decision: {
      type: string;
      actor_user_id: string;
      acknowledged_at: string;
      idempotent?: boolean;
    };
  } | null;
};

export function get_legal_governance_action_service() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

function resolve_selected_governance_scope(ctx: NonNullable<Awaited<ReturnType<typeof get_access_context>>>) {
  const selected_membership =
    (ctx.current_context
      ? ctx.memberships.find((membership) => membership.id === ctx.current_context?.membership_id)
      : null) ?? ctx.memberships[0] ?? null;

  if (!selected_membership?.company_id) return null;

  return {
    org_id: selected_membership.org_id,
    company_id: selected_membership.company_id,
    branch_id: selected_membership.branch_id,
    environment_type: selected_membership.environment_type,
    is_demo: selected_membership.is_demo
  };
}

export async function get_legal_governance_action_context(
  request: Request,
  schema_version: string
): Promise<ActionContext> {
  const ctx = await get_access_context(request);
  if (!ctx) {
    return {
      response: fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401),
      ctx: null,
      scope: null,
      service: null
    };
  }

  const scope = resolve_selected_governance_scope(ctx);
  if (!scope || !can_write_governance(ctx, scope)) {
    return {
      response: fail(schema_version, "SCOPE_FORBIDDEN", "Governance action is not allowed in the selected scope", 403),
      ctx,
      scope: null,
      service: null
    };
  }

  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) {
    return {
      response: previewError,
      ctx,
      scope: null,
      service: null
    };
  }

  const service = get_legal_governance_action_service();
  if (!service) {
    return {
      response: fail(schema_version, "INTERNAL_ERROR", "Supabase service role config is missing", 500),
      ctx,
      scope,
      service: null
    };
  }

  return {
    response: null,
    ctx,
    scope,
    service
  };
}

function map_acknowledge_error(
  schema_version: string,
  error: { message?: string | null; details?: string | null; hint?: string | null } | null
) {
  const raw = [error?.message ?? "", error?.details ?? "", error?.hint ?? ""].join(" ").toUpperCase();

  if (raw.includes("CHECK_NOT_FOUND")) {
    return fail(schema_version, "CHECK_NOT_FOUND", "Governance check not found", 404);
  }
  if (raw.includes("SCOPE_FORBIDDEN")) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Governance check is not accessible in the selected scope", 403);
  }
  if (raw.includes("REQUEST_ALREADY_RESOLVED")) {
    return fail(schema_version, "REQUEST_ALREADY_RESOLVED", "Governance check is already in a final state", 409);
  }
  if (raw.includes("INVALID_REQUEST")) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid governance acknowledge request", 400);
  }

  return fail(schema_version, "INTERNAL_ERROR", "Failed to acknowledge governance warning", 500);
}

export async function acknowledge_governance_warning_action(
  service: any,
  schema_version: string,
  payload: {
    check_id: string;
    actor_user_id: string;
    scope: {
      org_id: string;
      company_id: string;
      branch_id: string | null;
      environment_type: string;
    };
    reason: string | null;
  }
): Promise<AcknowledgeResult> {
  const { data, error } = await service.rpc("acknowledge_governance_warning", {
    p_payload: {
      check_id: payload.check_id,
      actor_user_id: payload.actor_user_id,
      org_id: payload.scope.org_id,
      company_id: payload.scope.company_id,
      branch_id: payload.scope.branch_id,
      environment_type: payload.scope.environment_type,
      reason: payload.reason
    }
  });

  if (error || !data) {
    return {
      response: map_acknowledge_error(schema_version, error),
      data: null
    };
  }

  return {
    response: null,
    data: {
      check_id: data.check_id,
      company_decision_status: data.company_decision_status,
      decision: data.decision
    }
  };
}

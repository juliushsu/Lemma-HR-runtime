import { fail, ok } from "../../../_lib";
import { acknowledge_governance_warning_action, get_legal_governance_action_context } from "../../_actions";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, { params }: Params) {
  const schema_version = "legal.governance.decision.v1";
  const context = await get_legal_governance_action_context(request, schema_version);
  if (context.response || !context.ctx || !context.scope || !context.service) return context.response;

  const { id } = await params;
  if (!id) {
    return fail(schema_version, "INVALID_REQUEST", "Governance check id is required", 400);
  }

  let body: Record<string, unknown> = {};
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    body = {};
  }

  const rawReason = body.reason;
  if (rawReason !== undefined && rawReason !== null && typeof rawReason !== "string") {
    return fail(schema_version, "INVALID_REQUEST", "reason must be a string when provided", 400);
  }

  const reason = typeof rawReason === "string" ? rawReason.trim() || null : null;

  const result = await acknowledge_governance_warning_action(context.service, schema_version, {
    check_id: id,
    actor_user_id: context.ctx.user_id,
    scope: context.scope,
    reason
  });
  if (result.response || !result.data) return result.response;

  return ok(schema_version, {
    check_id: result.data.check_id,
    company_decision_status: result.data.company_decision_status,
    decision: {
      type: result.data.decision.type,
      actor_user_id: result.data.decision.actor_user_id,
      acknowledged_at: result.data.decision.acknowledged_at
    }
  });
}

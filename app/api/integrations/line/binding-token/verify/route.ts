import { ok, fail } from "../../../../hr/_lib";
import { get_service_supabase, hash_token } from "../../_lib";

export async function POST(request: Request) {
  const schema_version = "integration.line.binding_token.verify.v1";
  const body = (await request.json()) as Record<string, unknown>;
  const token = String(body.binding_token ?? "");
  if (!token) return fail(schema_version, "INVALID_REQUEST", "binding_token is required", 400);

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const token_hash = hash_token(token);
  const { data: token_row, error } = await service
    .from("line_binding_tokens")
    .select("id,org_id,company_id,branch_id,environment_type,is_demo,employee_id,user_id,expires_at,status,consumed_at")
    .eq("token_hash", token_hash)
    .maybeSingle();

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to verify binding token", 500);
  if (!token_row) return fail(schema_version, "INVALID_BINDING_TOKEN", "Binding token is invalid", 404);

  const now = Date.now();
  const expiresAt = new Date(token_row.expires_at).getTime();
  if (token_row.status !== "pending" || token_row.consumed_at) {
    return fail(schema_version, "BINDING_TOKEN_ALREADY_USED", "Binding token is already used", 409);
  }
  if (Number.isFinite(expiresAt) && expiresAt <= now) {
    await service
      .from("line_binding_tokens")
      .update({ status: "expired" })
      .eq("id", token_row.id);
    return fail(schema_version, "BINDING_TOKEN_EXPIRED", "Binding token is expired", 410);
  }

  return ok(schema_version, {
    valid: true,
    binding_token_id: token_row.id,
    employee_id: token_row.employee_id,
    user_id: token_row.user_id,
    org_id: token_row.org_id,
    company_id: token_row.company_id,
    branch_id: token_row.branch_id,
    environment_type: token_row.environment_type,
    is_demo: token_row.is_demo,
    expires_at: token_row.expires_at
  });
}


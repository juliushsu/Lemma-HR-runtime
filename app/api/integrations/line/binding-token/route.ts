import { ok, fail, get_access_context, resolve_scope, can_write, apply_scope } from "../../../hr/_lib";
import { get_service_supabase, hash_token, issue_plain_token, token_last4 } from "../_lib";

export async function POST(request: Request) {
  const schema_version = "integration.line.binding_token.generate.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_write(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not writable", 403);
  }

  const body = (await request.json()) as Record<string, unknown>;
  const employee_id = String(body.employee_id ?? "");
  const requested_user_id = body.user_id ? String(body.user_id) : null;
  const expires_in_minutes_raw = Number(body.expires_in_minutes ?? 15);
  const expires_in_minutes = Math.min(60, Math.max(1, Number.isFinite(expires_in_minutes_raw) ? expires_in_minutes_raw : 15));

  if (!employee_id) {
    return fail(schema_version, "INVALID_REQUEST", "employee_id is required", 400);
  }

  const { data: employee, error: employee_error } = await apply_scope(
    ctx.supabase.from("employees").select("id,branch_id"),
    scope
  )
    .eq("id", employee_id)
    .maybeSingle();

  if (employee_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const token = issue_plain_token();
  const token_hash = hash_token(token);
  const expires_at = new Date(Date.now() + expires_in_minutes * 60 * 1000).toISOString();

  const { data: created, error: create_error } = await service
    .from("line_binding_tokens")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: employee.branch_id ?? scope.branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      employee_id: employee.id,
      user_id: requested_user_id,
      token_hash,
      token_last4: token_last4(token),
      expires_at,
      status: "pending",
      created_by: ctx.user_id
    })
    .select("id,employee_id,expires_at,token_last4")
    .maybeSingle();

  if (create_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to generate binding token", 500);
  }

  const binding_base_url =
    process.env.LINE_BINDING_BASE_URL ??
    process.env.NEXT_PUBLIC_APP_URL ??
    process.env.APP_BASE_URL ??
    "";
  const binding_url = binding_base_url
    ? `${binding_base_url.replace(/\/$/, "")}/line/bind?token=${encodeURIComponent(token)}`
    : null;

  return ok(schema_version, {
    binding_token: token,
    binding_token_id: created?.id ?? null,
    employee_id: created?.employee_id ?? employee.id,
    expires_at: created?.expires_at ?? expires_at,
    token_last4: created?.token_last4 ?? token_last4(token),
    binding_url,
    binding_qr_payload: binding_url ?? token
  }, 201);
}

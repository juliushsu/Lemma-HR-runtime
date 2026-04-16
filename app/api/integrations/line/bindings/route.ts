import { ok, fail } from "../../../hr/_lib";
import { get_service_supabase, hash_token, line_bot_reply, resolve_line_locale } from "../_lib";

export async function POST(request: Request) {
  const schema_version = "integration.line.binding.create.v1";
  const body = (await request.json()) as Record<string, unknown>;
  const token = String(body.binding_token ?? "");
  const line_user_id = String(body.line_user_id ?? "");
  const line_display_name = body.line_display_name ? String(body.line_display_name) : null;
  const requested_locale = body.locale ? String(body.locale) : null;
  const locale_info = resolve_line_locale({ payload_locale: requested_locale });

  if (!token || !line_user_id) {
    return fail(schema_version, "INVALID_REQUEST", "binding_token and line_user_id are required", 400, {
      bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
    });
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500, {
    bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
  });

  const token_hash = hash_token(token);
  const { data: token_row, error: token_error } = await service
    .from("line_binding_tokens")
    .select("id,org_id,company_id,branch_id,environment_type,is_demo,employee_id,user_id,expires_at,status,consumed_at")
    .eq("token_hash", token_hash)
    .maybeSingle();

  if (token_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch binding token", 500, {
    bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
  });
  if (!token_row) return fail(schema_version, "INVALID_BINDING_TOKEN", "Binding token is invalid", 404, {
    bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
  });

  if (token_row.status !== "pending" || token_row.consumed_at) {
    return fail(schema_version, "BINDING_TOKEN_ALREADY_USED", "Binding token is already used", 409, {
      bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
    });
  }

  const expires_at_ms = new Date(token_row.expires_at).getTime();
  if (Number.isFinite(expires_at_ms) && expires_at_ms <= Date.now()) {
    await service.from("line_binding_tokens").update({ status: "expired" }).eq("id", token_row.id);
    return fail(schema_version, "BINDING_TOKEN_EXPIRED", "Binding token is expired", 410, {
      bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
    });
  }

  const { data: existing_line_binding } = await service
    .from("line_bindings")
    .select("id,employee_id,bind_status,environment_type")
    .eq("line_user_id", line_user_id)
    .eq("environment_type", token_row.environment_type)
    .maybeSingle();

  if (
    existing_line_binding &&
    existing_line_binding.bind_status === "active" &&
    existing_line_binding.employee_id !== token_row.employee_id
  ) {
    return fail(schema_version, "LINE_USER_ALREADY_BOUND", "line_user_id is already bound to another employee", 409, {
      bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
    });
  }

  // One active binding per employee per environment.
  await service
    .from("line_bindings")
    .update({
      bind_status: "revoked",
      revoked_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    })
    .eq("employee_id", token_row.employee_id)
    .eq("environment_type", token_row.environment_type)
    .eq("bind_status", "active");

  const nowIso = new Date().toISOString();
  const { data: bound, error: bind_error } = await service
    .from("line_bindings")
    .upsert({
      org_id: token_row.org_id,
      company_id: token_row.company_id,
      branch_id: token_row.branch_id,
      environment_type: token_row.environment_type,
      is_demo: token_row.is_demo,
      line_user_id,
      line_display_name,
      user_id: token_row.user_id,
      employee_id: token_row.employee_id,
      bind_status: "active",
      bound_at: nowIso,
      last_seen_at: nowIso,
      revoked_at: null,
      updated_at: nowIso,
      updated_by: token_row.user_id
    }, { onConflict: "line_user_id,environment_type" })
    .select("id,line_user_id,employee_id,user_id,environment_type,bind_status,bound_at")
    .maybeSingle();

  if (bind_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to bind line_user_id", 500, {
    bot_reply: line_bot_reply("line.binding.failed", locale_info.locale)
  });

  await service
    .from("line_binding_tokens")
    .update({
      status: "consumed",
      consumed_at: nowIso
    })
    .eq("id", token_row.id);

  return ok(schema_version, {
    binding_id: bound?.id ?? null,
    line_user_id: bound?.line_user_id ?? line_user_id,
    employee_id: bound?.employee_id ?? token_row.employee_id,
    user_id: bound?.user_id ?? token_row.user_id,
    environment_type: bound?.environment_type ?? token_row.environment_type,
    bind_status: bound?.bind_status ?? "active",
    bound_at: bound?.bound_at ?? nowIso,
    bot_reply: line_bot_reply("line.binding.success", locale_info.locale, {
      requested_locale: locale_info.requested_locale
    })
  }, 201);
}

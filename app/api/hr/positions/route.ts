import { ok, fail, get_access_context, resolve_scope, can_read, apply_scope } from "../_lib";

export async function GET(request: Request) {
  const schema_version = "hr.position.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const { data, error } = await apply_scope(
    ctx.supabase
      .from("positions")
      .select("id,position_code,position_name,job_level,is_managerial,is_active"),
    scope
  ).order("position_code", { ascending: true });

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch positions", 500);
  return ok(schema_version, { items: data ?? [] });
}


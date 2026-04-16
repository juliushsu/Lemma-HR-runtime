import { get_scoped_context, success, failure, parse_json_body } from "../../_attendance_phase1";
import { list_source_items } from "../_lib";

export async function POST(request: Request) {
  const rawBody = await request.text();
  const body = parse_json_body(rawBody);
  if (body === null) return failure("INVALID_JSON", "Request body must be valid JSON", 400);

  const scoped = await get_scoped_context(request, { write: true, body });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;
  const defaultEnabledKeys = new Set(
    Array.isArray(body.default_enabled_keys)
      ? body.default_enabled_keys.filter((v): v is string => typeof v === "string")
      : []
  );

  const [{ data: types, error: type_error }, { data: existing, error: existing_error }] = await Promise.all([
    ctx.supabase.from("attendance_source_types").select("key"),
    ctx.supabase
      .from("attendance_sources")
      .select("source_key")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
  ]);

  if (type_error || existing_error) {
    return failure("INTERNAL_ERROR", "Failed to bootstrap attendance sources", 500);
  }

  const existingKeys = new Set((existing ?? []).map((row) => row.source_key as string));
  const pendingRows = (types ?? [])
    .map((row) => row.key as string)
    .filter((key) => !existingKeys.has(key))
    .map((source_key) => ({
      org_id: scope.org_id,
      company_id: scope.company_id,
      source_key,
      is_enabled: defaultEnabledKeys.has(source_key),
      config: {}
    }));

  if (pendingRows.length > 0) {
    const { error: insert_error } = await ctx.supabase.from("attendance_sources").insert(pendingRows);
    if (insert_error) {
      return failure("INTERNAL_ERROR", "Failed to create bootstrap attendance sources", 500, {
        detail: insert_error.message
      });
    }
  }

  const { items, error } = await list_source_items(ctx, scope);
  if (error) return failure("INTERNAL_ERROR", "Failed to fetch attendance sources after bootstrap", 500, { detail: error });

  return success(
    {
      org_id: scope.org_id,
      company_id: scope.company_id,
      inserted_count: pendingRows.length,
      items: items ?? []
    },
    201
  );
}

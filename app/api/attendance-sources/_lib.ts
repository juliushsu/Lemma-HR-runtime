import { type AccessContext, type Scope } from "../hr/_lib";

export async function list_source_items(ctx: AccessContext, scope: Scope) {
  const [{ data: types, error: type_error }, { data: sources, error: source_error }] = await Promise.all([
    ctx.supabase
      .from("attendance_source_types")
      .select("key,label_zh,label_en,label_ja,sort_order,is_built_in")
      .order("sort_order", { ascending: true }),
    ctx.supabase
      .from("attendance_sources")
      .select("id,org_id,company_id,source_key,is_enabled,config,created_at,updated_at")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .order("created_at", { ascending: true })
  ]);

  if (type_error || source_error) {
    return { items: null, error: type_error?.message ?? source_error?.message ?? "Unknown error" };
  }

  const source_rows = (sources ?? []) as any[];
  const source_map = new Map(source_rows.map((s) => [s.source_key as string, s]));
  const type_items = (types ?? []).map((t) => {
    const source = source_map.get(t.key);
    return {
      key: t.key,
      label_zh: t.label_zh,
      label_en: t.label_en,
      label_ja: t.label_ja,
      sort_order: t.sort_order,
      is_built_in: t.is_built_in,
      id: source?.id ?? null,
      is_enabled: source?.is_enabled ?? false,
      config: source?.config ?? {},
      created_at: source?.created_at ?? null,
      updated_at: source?.updated_at ?? null
    };
  });

  const custom_items = source_rows
    .filter((s) => !type_items.some((item) => item.key === s.source_key))
    .map((s) => ({
      key: s.source_key,
      label_zh: s.source_key,
      label_en: s.source_key,
      label_ja: s.source_key,
      sort_order: 999,
      is_built_in: false,
      id: s.id,
      is_enabled: s.is_enabled,
      config: s.config ?? {},
      created_at: s.created_at,
      updated_at: s.updated_at
    }));

  return { items: [...type_items, ...custom_items], error: null };
}

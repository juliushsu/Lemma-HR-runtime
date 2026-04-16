import { fail, get_access_context, ok, resolve_scope, scopedQuery, reject_preview_override_write } from "../_lib";

const CASE_TYPES = new Set([
  "labor_dispute",
  "contract_breach",
  "payment_dispute",
  "procurement_dispute",
  "ip_dispute",
  "other"
]);

const CASE_STATUSES = new Set(["open", "under_review", "strategy_prepared", "external_counsel", "closed"]);

export async function GET(request: Request) {
  const schema_version = "legal.case.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(request, ctx);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const url = new URL(request.url);
  const case_type = url.searchParams.get("case_type");
  const status = url.searchParams.get("status");
  const keyword = url.searchParams.get("keyword");

  let query = scopedQuery(
    ctx.supabase
      .from("legal_cases")
      .select("*")
      .order("updated_at", { ascending: false }),
    scope
  );

  if (case_type) query = query.eq("case_type", case_type);
  if (status) query = query.eq("status", status);
  if (keyword) query = query.or(`case_code.ilike.%${keyword}%,title.ilike.%${keyword}%`);

  const { data, error } = await query;
  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch legal cases", 500);
  return ok(schema_version, { items: data ?? [] });
}

export async function POST(request: Request) {
  const schema_version = "legal.case.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const body = (await request.json()) as Record<string, unknown>;
  const scope = resolve_scope(request, ctx, body);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const case_code = String(body.case_code ?? "").trim();
  const case_type = String(body.case_type ?? "").trim();
  const title = String(body.title ?? "").trim();
  const status = String(body.status ?? "open").trim();
  if (!case_code || !title || !CASE_TYPES.has(case_type) || !CASE_STATUSES.has(status)) {
    return fail(schema_version, "INVALID_REQUEST", "case_code/case_type/title/status are invalid", 400);
  }

  const { data, error } = await ctx.supabase
    .from("legal_cases")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: scope.branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      case_code,
      case_type,
      title,
      status,
      governing_law_code: body.governing_law_code ?? null,
      forum_note: body.forum_note ?? null,
      risk_level: body.risk_level ?? null,
      summary: body.summary ?? null,
      owner_user_id: body.owner_user_id ?? ctx.user_id,
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id")
    .maybeSingle();

  if (error) {
    if ((error as { code?: string }).code === "23505") {
      return fail(schema_version, "LEGAL_CASE_CODE_ALREADY_EXISTS", "Case code already exists", 409);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create legal case", 500);
  }

  return ok(schema_version, { legal_case_id: data?.id ?? null }, 201);
}

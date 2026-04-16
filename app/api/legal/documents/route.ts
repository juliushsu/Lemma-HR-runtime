import { fail, get_access_context, ok, resolve_scope, scopedQuery, reject_preview_override_write } from "../_lib";

const ALLOWED_DOCUMENT_TYPES = new Set([
  "employment_contract",
  "procurement_contract",
  "sales_contract",
  "nda",
  "policy",
  "memo",
  "other"
]);

export async function GET(request: Request) {
  const schema_version = "legal.document.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(request, ctx);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const url = new URL(request.url);
  const document_type = url.searchParams.get("document_type");
  const source_module = url.searchParams.get("source_module");
  const keyword = url.searchParams.get("keyword");

  let query = scopedQuery(
    ctx.supabase
      .from("legal_documents")
      .select("*")
      .order("updated_at", { ascending: false }),
    scope
  );

  if (document_type) query = query.eq("document_type", document_type);
  if (source_module) query = query.eq("source_module", source_module);
  if (keyword) query = query.or(`document_code.ilike.%${keyword}%,title.ilike.%${keyword}%,counterparty_name.ilike.%${keyword}%`);

  const { data, error } = await query;
  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch legal documents", 500);

  return ok(schema_version, { items: data ?? [] });
}

export async function POST(request: Request) {
  const schema_version = "legal.document.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const body = (await request.json()) as Record<string, unknown>;
  const scope = resolve_scope(request, ctx, body);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const document_code = String(body.document_code ?? "").trim();
  const title = String(body.title ?? "").trim();
  const document_type = String(body.document_type ?? "").trim();
  if (!document_code || !title || !ALLOWED_DOCUMENT_TYPES.has(document_type)) {
    return fail(schema_version, "INVALID_REQUEST", "document_code/title/document_type are invalid", 400);
  }

  const payload = {
    org_id: scope.org_id,
    company_id: scope.company_id,
    branch_id: scope.branch_id,
    environment_type: scope.environment_type,
    is_demo: scope.is_demo,
    document_code,
    title,
    document_type,
    governing_law_code: body.governing_law_code ?? null,
    jurisdiction_note: body.jurisdiction_note ?? null,
    counterparty_name: body.counterparty_name ?? null,
    counterparty_type: body.counterparty_type ?? null,
    effective_date: body.effective_date ?? null,
    expiry_date: body.expiry_date ?? null,
    auto_renewal_date: body.auto_renewal_date ?? null,
    signing_status: body.signing_status ?? "draft",
    source_module: body.source_module ?? null,
    source_record_id: body.source_record_id ?? null,
    created_by: ctx.user_id,
    updated_by: ctx.user_id
  };

  const { data, error } = await ctx.supabase.from("legal_documents").insert(payload).select("id").maybeSingle();
  if (error) {
    if ((error as { code?: string }).code === "23505") {
      return fail(schema_version, "DOCUMENT_CODE_ALREADY_EXISTS", "Document code already exists", 409);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create legal document", 500);
  }

  return ok(schema_version, { legal_document_id: data?.id ?? null }, 201);
}

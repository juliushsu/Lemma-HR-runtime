import { fail, get_access_context, ok, resolve_scope, scopedQuery, reject_preview_override_write } from "../../../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, { params }: Params) {
  const schema_version = "legal.case.documents.list.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const { id } = await params;
  const scope = resolve_scope(request, ctx);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const { data: legalCase } = await scopedQuery(
    ctx.supabase.from("legal_cases").select("id"),
    scope
  )
    .eq("id", id)
    .maybeSingle();
  if (!legalCase) return fail(schema_version, "LEGAL_CASE_NOT_FOUND", "Legal case not found", 404);

  const { data, error } = await scopedQuery(
    ctx.supabase
      .from("legal_case_documents")
      .select("id,relationship_type,legal_document_id,legal_documents(id,document_code,title,document_type,signing_status)"),
    scope
  )
    .eq("legal_case_id", id)
    .order("created_at", { ascending: false });

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch case documents", 500);
  return ok(schema_version, { items: data ?? [] });
}

export async function POST(request: Request, { params }: Params) {
  const schema_version = "legal.case.documents.link.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const body = (await request.json()) as Record<string, unknown>;
  const { id } = await params;
  const scope = resolve_scope(request, ctx, body);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const legal_document_id = String(body.legal_document_id ?? "").trim();
  if (!legal_document_id) return fail(schema_version, "INVALID_REQUEST", "legal_document_id is required", 400);

  const [{ data: legalCase }, { data: document }] = await Promise.all([
    scopedQuery(ctx.supabase.from("legal_cases").select("id"), scope).eq("id", id).maybeSingle(),
    scopedQuery(ctx.supabase.from("legal_documents").select("id"), scope).eq("id", legal_document_id).maybeSingle()
  ]);
  if (!legalCase) return fail(schema_version, "LEGAL_CASE_NOT_FOUND", "Legal case not found", 404);
  if (!document) return fail(schema_version, "LEGAL_DOCUMENT_NOT_FOUND", "Legal document not found", 404);

  const { data, error } = await ctx.supabase
    .from("legal_case_documents")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: scope.branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      legal_case_id: id,
      legal_document_id,
      relationship_type: body.relationship_type ?? "evidence",
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id")
    .maybeSingle();

  if (error) {
    if ((error as { code?: string }).code === "23505") {
      return fail(schema_version, "LEGAL_CASE_DOCUMENT_ALREADY_LINKED", "Document is already linked to case", 409);
    }
    return fail(schema_version, "INTERNAL_ERROR", "Failed to link legal case document", 500);
  }

  return ok(schema_version, { legal_case_document_id: data?.id ?? null }, 201);
}

import { fail, get_access_context, ok, resolve_scope, scopedQuery } from "../../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, { params }: Params) {
  const schema_version = "legal.document.detail.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const { id } = await params;
  const scope = resolve_scope(request, ctx);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const { data: document, error: documentError } = await scopedQuery(
    ctx.supabase.from("legal_documents").select("*"),
    scope
  )
    .eq("id", id)
    .maybeSingle();

  if (documentError) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch legal document", 500);
  if (!document) return fail(schema_version, "LEGAL_DOCUMENT_NOT_FOUND", "Legal document not found", 404);

  const [{ data: versions }, { data: tags }] = await Promise.all([
    scopedQuery(
      ctx.supabase.from("legal_document_versions").select("*"),
      scope
    )
      .eq("legal_document_id", id)
      .order("version_no", { ascending: false }),
    scopedQuery(
      ctx.supabase.from("legal_document_tags").select("id,tag"),
      scope
    )
      .eq("legal_document_id", id)
      .order("tag", { ascending: true })
  ]);

  return ok(schema_version, {
    legal_document: document,
    versions: versions ?? [],
    tags: tags ?? []
  });
}


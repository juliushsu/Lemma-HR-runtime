import { fail, get_access_context, ok, resolve_scope, scopedQuery } from "../../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

export async function GET(request: Request, { params }: Params) {
  const schema_version = "legal.case.detail.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const { id } = await params;
  const scope = resolve_scope(request, ctx);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const { data: legalCase, error: caseError } = await scopedQuery(
    ctx.supabase.from("legal_cases").select("*"),
    scope
  )
    .eq("id", id)
    .maybeSingle();

  if (caseError) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch legal case", 500);
  if (!legalCase) return fail(schema_version, "LEGAL_CASE_NOT_FOUND", "Legal case not found", 404);

  const [{ data: linkedDocuments, error: linkError }, { data: events, error: eventError }] = await Promise.all([
    scopedQuery(
      ctx.supabase
        .from("legal_case_documents")
        .select("id,relationship_type,legal_document_id,legal_documents(id,document_code,title,document_type,signing_status)"),
      scope
    )
      .eq("legal_case_id", id)
      .order("created_at", { ascending: false }),
    scopedQuery(
      ctx.supabase
        .from("legal_case_events")
        .select("id,event_date,event_type,description,source_document_id,created_at,created_by"),
      scope
    )
      .eq("legal_case_id", id)
      .order("event_date", { ascending: false })
      .order("created_at", { ascending: false })
  ]);

  if (linkError || eventError) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch legal case details", 500);

  return ok(schema_version, {
    legal_case: legalCase,
    linked_documents: linkedDocuments ?? [],
    case_events: events ?? []
  });
}


import { fail, get_access_context, ok, resolve_scope, scopedQuery, reject_preview_override_write } from "../../../_lib";

type Params = {
  params: Promise<{ id: string }>;
};

export async function POST(request: Request, { params }: Params) {
  const schema_version = "legal.document.version.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const body = (await request.json()) as Record<string, unknown>;
  const { id } = await params;
  const scope = resolve_scope(request, ctx, body);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const { data: document } = await scopedQuery(
    ctx.supabase.from("legal_documents").select("id"),
    scope
  )
    .eq("id", id)
    .maybeSingle();
  if (!document) return fail(schema_version, "LEGAL_DOCUMENT_NOT_FOUND", "Legal document not found", 404);

  const { data: maxVersionRow } = await scopedQuery(
    ctx.supabase
      .from("legal_document_versions")
      .select("version_no")
      .eq("legal_document_id", id)
      .order("version_no", { ascending: false })
      .limit(1),
    scope
  ).maybeSingle();
  const nextVersionNo = (maxVersionRow?.version_no ?? 0) + 1;

  const file_name = String(body.file_name ?? "").trim();
  const storage_path = String(body.storage_path ?? "").trim();
  if (!file_name || !storage_path) {
    return fail(schema_version, "INVALID_REQUEST", "file_name and storage_path are required", 400);
  }

  const { data: version, error } = await ctx.supabase
    .from("legal_document_versions")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: scope.branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      legal_document_id: id,
      version_no: nextVersionNo,
      storage_path,
      file_name,
      file_ext: body.file_ext ?? null,
      mime_type: body.mime_type ?? null,
      file_size_bytes: body.file_size_bytes ?? null,
      checksum: body.checksum ?? null,
      uploaded_by: ctx.user_id,
      is_current: true,
      parsed_status: "pending",
      created_by: ctx.user_id,
      updated_by: ctx.user_id
    })
    .select("id,version_no")
    .maybeSingle();

  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to create legal document version", 500);

  await scopedQuery(
    ctx.supabase.from("legal_document_versions"),
    scope
  )
    .update({ is_current: false, updated_by: ctx.user_id, updated_at: new Date().toISOString() })
    .eq("legal_document_id", id)
    .neq("id", version?.id ?? "");

  await scopedQuery(
    ctx.supabase.from("legal_documents"),
    scope
  )
    .update({ current_version_id: version?.id ?? null, updated_by: ctx.user_id, updated_at: new Date().toISOString() })
    .eq("id", id);

  return ok(schema_version, {
    legal_document_version_id: version?.id ?? null,
    version_no: version?.version_no ?? null
  }, 201);
}

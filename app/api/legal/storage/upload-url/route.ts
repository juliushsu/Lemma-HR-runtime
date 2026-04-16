import { fail, get_access_context, ok, resolve_scope, scopedQuery, reject_preview_override_write } from "../../_lib";

type UploadPathParts = {
  org_id: string;
  company_id: string;
  environment_type: string;
  legal_document_id: string;
  version_no: number;
  file_name: string;
};

function sanitizeFileName(name: string) {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function buildUploadPath(parts: UploadPathParts) {
  return [
    parts.org_id,
    parts.company_id,
    parts.environment_type,
    parts.legal_document_id,
    `v${parts.version_no}`,
    sanitizeFileName(parts.file_name)
  ].join("/");
}

export async function POST(request: Request) {
  const schema_version = "legal.storage.upload_url.create.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);
  const previewError = reject_preview_override_write(schema_version, ctx);
  if (previewError) return previewError;

  const body = (await request.json()) as Record<string, unknown>;
  const scope = resolve_scope(request, ctx, body);
  if (!scope) return fail(schema_version, "SCOPE_FORBIDDEN", "Scope not accessible", 403);

  const legal_document_id = String(body.legal_document_id ?? "").trim();
  const file_name = String(body.file_name ?? "").trim();
  if (!legal_document_id || !file_name) {
    return fail(schema_version, "INVALID_REQUEST", "legal_document_id and file_name are required", 400);
  }

  const { data: document } = await scopedQuery(
    ctx.supabase.from("legal_documents").select("id"),
    scope
  )
    .eq("id", legal_document_id)
    .maybeSingle();
  if (!document) return fail(schema_version, "LEGAL_DOCUMENT_NOT_FOUND", "Legal document not found", 404);

  const { data: maxVersion } = await scopedQuery(
    ctx.supabase
      .from("legal_document_versions")
      .select("version_no")
      .eq("legal_document_id", legal_document_id)
      .order("version_no", { ascending: false })
      .limit(1),
    scope
  ).maybeSingle();
  const nextVersion = (maxVersion?.version_no ?? 0) + 1;

  const uploadPath = buildUploadPath({
    org_id: scope.org_id,
    company_id: scope.company_id,
    environment_type: scope.environment_type,
    legal_document_id,
    version_no: nextVersion,
    file_name
  });

  const bucket = process.env.LEGAL_DOCUMENTS_BUCKET ?? "legal-documents";
  const { data, error } = await ctx.supabase.storage.from(bucket).createSignedUploadUrl(uploadPath);
  if (error) return fail(schema_version, "INTERNAL_ERROR", "Failed to create signed upload url", 500);

  return ok(schema_version, {
    bucket,
    path: uploadPath,
    token: data?.token ?? null,
    signed_url: data?.signedUrl ?? null,
    next_version_no: nextVersion
  });
}

import { ok, fail, get_access_context, resolve_scope, can_read, apply_scope } from "../../hr/_lib";

export async function GET(request: Request) {
  const schema_version = "settings.company_profile.v1";
  const ctx = await get_access_context(request);
  if (!ctx) return fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401);

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403);
  }

  const [{ data: company, error: company_error }, { data: settings, error: settings_error }] = await Promise.all([
    ctx.supabase
      .from("companies")
      .select("id,name,locale_default")
      .eq("org_id", scope.org_id)
      .eq("id", scope.company_id)
      .eq("environment_type", scope.environment_type)
      .maybeSingle(),
    apply_scope(
      ctx.supabase
        .from("company_settings")
        .select("company_legal_name,tax_id,address,timezone,default_locale,is_attendance_enabled"),
      scope
    ).maybeSingle()
  ]);

  if (company_error || settings_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch company profile", 500);
  }
  if (!company) return fail(schema_version, "COMPANY_NOT_FOUND", "Company not found", 404);

  const company_profile = {
    org_id: scope.org_id,
    company_id: scope.company_id,
    company_name: company.name,
    company_legal_name: settings?.company_legal_name ?? company.name,
    tax_id: settings?.tax_id ?? null,
    address: settings?.address ?? null,
    timezone: settings?.timezone ?? "Asia/Taipei",
    default_locale: settings?.default_locale ?? company.locale_default ?? "en",
    is_attendance_enabled: settings?.is_attendance_enabled ?? true
  };

  // Keep nested shape and expose flattened aliases for compatibility with existing UI/smoke readers.
  return ok(schema_version, {
    ...company_profile,
    company_profile
  });
}

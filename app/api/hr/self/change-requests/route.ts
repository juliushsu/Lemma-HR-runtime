import { createClient } from "@supabase/supabase-js";
import { AccessContext, Scope, apply_scope, can_read, fail, get_access_context, ok, reject_preview_override_write, resolve_scope } from "../../_lib";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

const SUPPORTED_FIELDS = [
  "personal_email",
  "mobile_phone",
  "emergency_contact_name",
  "emergency_contact_phone",
  "preferred_name"
] as const;

const SUPPORTED_FIELD_SET = new Set<string>(SUPPORTED_FIELDS);
const SUPPORTED_STATUSES = new Set(["pending", "approved", "rejected"]);

type SupportedField = (typeof SUPPORTED_FIELDS)[number];

type SelfEmployee = {
  id: string;
  employee_code: string;
  org_id: string;
  company_id: string;
  branch_id: string | null;
  environment_type: string;
  is_demo: boolean;
  work_email: string | null;
  personal_email: string | null;
  preferred_name: string | null;
  mobile_phone: string | null;
  emergency_contact_name: string | null;
  emergency_contact_phone: string | null;
};

function get_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

function is_self_write_blocked(ctx: AccessContext) {
  return ctx.current_context?.access_mode === "read_only_demo";
}

async function list_scoped_self_candidates(service: any, scope: Scope) {
  const { data, error } = await apply_scope(
    service
      .from("employees")
      .select(
        "id,employee_code,org_id,company_id,branch_id,environment_type,is_demo,work_email,personal_email,preferred_name,mobile_phone,emergency_contact_name,emergency_contact_phone"
      ),
    scope
  ).order("employee_code", { ascending: true });

  return {
    data: (data ?? []) as SelfEmployee[],
    error
  };
}

function resolve_self_employee(employees: SelfEmployee[], user_email: string | null) {
  const normalized = String(user_email ?? "").trim().toLowerCase();
  if (!normalized) {
    return {
      employee: null,
      ambiguous: false
    };
  }

  const matches = employees.filter((employee) => {
    const work = String(employee.work_email ?? "").trim().toLowerCase();
    const personal = String(employee.personal_email ?? "").trim().toLowerCase();
    return work === normalized || personal === normalized;
  });

  if (matches.length > 1) {
    return {
      employee: null,
      ambiguous: true
    };
  }

  return {
    employee: matches[0] ?? null,
    ambiguous: false
  };
}

function normalize_field_value(field_name: SupportedField, raw: unknown) {
  if (raw === null) return { ok: true, value: null as string | null };
  if (typeof raw !== "string") return { ok: false, value: null as string | null };

  const trimmed = raw.trim();
  if (!trimmed) return { ok: true, value: null as string | null };

  if (field_name === "personal_email") {
    return { ok: true, value: trimmed.toLowerCase() };
  }

  return { ok: true, value: trimmed };
}

function build_value_payload(value: string | null) {
  return { value };
}

function values_equal(left: string | null, right: string | null) {
  return (left ?? null) === (right ?? null);
}

function current_field_value(employee: SelfEmployee, field_name: SupportedField) {
  return (employee[field_name] ?? null) as string | null;
}

async function load_self_context(request: Request, schema_version: string) {
  const ctx = await get_access_context(request);
  if (!ctx) {
    return {
      response: fail(schema_version, "UNAUTHORIZED", "Unauthorized", 401),
      ctx: null,
      scope: null,
      service: null,
      employee: null
    };
  }

  const scope = resolve_scope(ctx, request);
  if (!scope || !can_read(ctx, scope)) {
    return {
      response: fail(schema_version, "SCOPE_FORBIDDEN", "Scope is not accessible", 403),
      ctx,
      scope: null,
      service: null,
      employee: null
    };
  }

  const service = get_service_supabase();
  if (!service) {
    return {
      response: fail(schema_version, "CONFIG_MISSING", "Supabase service role config is missing", 500),
      ctx,
      scope,
      service: null,
      employee: null
    };
  }

  const { data: employees, error } = await list_scoped_self_candidates(service, scope);
  if (error) {
    return {
      response: fail(schema_version, "INTERNAL_ERROR", "Failed to resolve self employee candidates", 500),
      ctx,
      scope,
      service,
      employee: null
    };
  }

  const resolved = resolve_self_employee(employees, ctx.user_email);
  if (resolved.ambiguous) {
    return {
      response: fail(
        schema_version,
        "EMPLOYEE_BINDING_AMBIGUOUS",
        "More than one employee matches the authenticated user in the selected context",
        409
      ),
      ctx,
      scope,
      service,
      employee: null
    };
  }

  if (!resolved.employee) {
    return {
      response: fail(
        schema_version,
        "EMPLOYEE_CONTEXT_REQUIRED",
        "Current user is not mapped to an employee in the selected context",
        400
      ),
      ctx,
      scope,
      service,
      employee: null
    };
  }

  return {
    response: null,
    ctx,
    scope,
    service,
    employee: resolved.employee
  };
}

export async function GET(request: Request) {
  const schema_version = "hr.self.change_requests.list.v1";

  const context_result = await load_self_context(request, schema_version);
  if (context_result.response || !context_result.ctx || !context_result.scope || !context_result.service || !context_result.employee) {
    return context_result.response;
  }

  const url = new URL(request.url);
  const requested_status = String(url.searchParams.get("status") ?? "").trim();
  if (requested_status && !SUPPORTED_STATUSES.has(requested_status)) {
    return fail(schema_version, "INVALID_REQUEST", "status must be pending, approved, or rejected", 400);
  }

  let query = apply_scope(
    context_result.service
      .from("employee_change_requests")
      .select("id,employee_id,field_name,old_value,new_value,status,requested_by,approved_by,created_at,resolved_at"),
    context_result.scope
  )
    .eq("employee_id", context_result.employee.id)
    .order("created_at", { ascending: false });

  if (requested_status) {
    query = query.eq("status", requested_status);
  }

  const { data: items, error } = await query;
  if (error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch self change requests", 500);
  }

  return ok(schema_version, {
    employee: {
      id: context_result.employee.id,
      employee_code: context_result.employee.employee_code
    },
    supported_fields: SUPPORTED_FIELDS,
    items: items ?? []
  });
}

export async function POST(request: Request) {
  const schema_version = "hr.self.change_requests.create.v1";

  const context_result = await load_self_context(request, schema_version);
  if (context_result.response || !context_result.ctx || !context_result.scope || !context_result.service || !context_result.employee) {
    return context_result.response;
  }

  const preview_error = reject_preview_override_write(schema_version, context_result.ctx);
  if (preview_error) return preview_error;
  if (is_self_write_blocked(context_result.ctx)) {
    return fail(schema_version, "SCOPE_FORBIDDEN", "Scope is read-only in the current context", 403);
  }

  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body) {
    return fail(schema_version, "INVALID_REQUEST", "Request body must be valid JSON", 400);
  }

  const field_name = String(body.field_name ?? "").trim();
  if (!SUPPORTED_FIELD_SET.has(field_name)) {
    return fail(
      schema_version,
      "UNSUPPORTED_CHANGE_FIELD",
      "field_name is not supported in Phase 1",
      400,
      { supported_fields: SUPPORTED_FIELDS }
    );
  }

  if (!Object.prototype.hasOwnProperty.call(body, "new_value")) {
    return fail(schema_version, "INVALID_REQUEST", "new_value is required", 400);
  }

  const normalized = normalize_field_value(field_name as SupportedField, body.new_value);
  if (!normalized.ok) {
    return fail(schema_version, "INVALID_REQUEST", "new_value must be a string or null", 400);
  }

  const old_value = current_field_value(context_result.employee, field_name as SupportedField);
  if (values_equal(old_value, normalized.value)) {
    return fail(schema_version, "NO_CHANGE_DETECTED", "Requested value matches current employee data", 409);
  }

  const insert_payload = {
    org_id: context_result.scope.org_id,
    company_id: context_result.scope.company_id,
    branch_id: context_result.employee.branch_id ?? context_result.scope.branch_id ?? null,
    environment_type: context_result.scope.environment_type,
    is_demo: context_result.scope.is_demo,
    employee_id: context_result.employee.id,
    field_name,
    old_value: build_value_payload(old_value),
    new_value: build_value_payload(normalized.value),
    status: "pending",
    requested_by: context_result.ctx.user_id,
    approved_by: null,
    resolved_at: null
  };

  const { data: item, error } = await context_result.service
    .from("employee_change_requests")
    .insert(insert_payload)
    .select("id,employee_id,field_name,old_value,new_value,status,requested_by,approved_by,created_at,resolved_at")
    .maybeSingle();

  if (error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create self change request", 500);
  }

  return ok(
    schema_version,
    {
      employee: {
        id: context_result.employee.id,
        employee_code: context_result.employee.employee_code
      },
      item
    },
    201
  );
}

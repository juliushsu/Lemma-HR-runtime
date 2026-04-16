import { createClient } from "@supabase/supabase-js";
import { fail, ok } from "../_lib";
import { get_leave_read_context, get_leave_write_context } from "../leave/_lib";
import {
  LeaveScopedEmployee,
  list_leave_scoped_employees,
  resolve_leave_locale_hint,
  resolve_leave_request_employee
} from "../leave/_locale";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

function get_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

function parse_timestamp(value: unknown) {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  const dt = new Date(raw);
  if (Number.isNaN(dt.getTime())) return null;
  return dt;
}

function iso_date(dt: Date) {
  return dt.toISOString().slice(0, 10);
}

function iso_time(dt: Date) {
  return dt.toISOString().slice(11, 19);
}

function build_approval_chain(employee: LeaveScopedEmployee, employee_map: Map<string, LeaveScopedEmployee>) {
  const seen = new Set<string>([employee.id]);
  const chain: LeaveScopedEmployee[] = [];
  let current = employee;

  while (current.manager_employee_id) {
    const manager = employee_map.get(current.manager_employee_id) ?? null;
    if (!manager) {
      return {
        chain,
        broken_manager_employee_id: current.manager_employee_id
      };
    }
    if (seen.has(manager.id)) {
      return {
        chain,
        broken_manager_employee_id: manager.id
      };
    }

    chain.push(manager);
    seen.add(manager.id);
    current = manager;
  }

  return {
    chain,
    broken_manager_employee_id: null
  };
}

export async function GET(request: Request) {
  const schema_version = "hr.leave_request_mvp.list.v1";
  const { response, ctx, scope } = await get_leave_read_context(request);
  if (response || !ctx || !scope) return response;

  const service = get_service_supabase();
  if (!service) {
    return fail(schema_version, "CONFIG_MISSING", "Supabase service role config is missing", 500);
  }

  const requested_employee_id = new URL(request.url).searchParams.get("employee_id");
  const { data: employees, error: employees_error } = await list_leave_scoped_employees(service, scope);
  if (employees_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve scoped employees", 500);
  }

  const employee = resolve_leave_request_employee(employees, requested_employee_id, ctx.user_email);
  const locale_hint = await resolve_leave_locale_hint(service, scope, employee, ctx.user_id);

  const { data, error } = await service
    .from("leave_requests")
    .select("id,status,current_step")
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .order("created_at", { ascending: false });

  if (error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch leave requests", 500);
  }

  return ok(schema_version, {
    resolved_locale: locale_hint.resolved_locale,
    locale_source: locale_hint.locale_source,
    items: (data ?? []).map((row: any) => ({
      id: row.id,
      status: row.status ?? "pending",
      current_step: row.current_step ?? 0
    }))
  });
}

export async function POST(request: Request) {
  const schema_version = "hr.leave_request_mvp.create.v1";
  const { response, ctx, scope } = await get_leave_write_context(request);
  if (response || !ctx || !scope) return response;

  const service = get_service_supabase();
  if (!service) {
    return fail(schema_version, "CONFIG_MISSING", "Supabase service role config is missing", 500);
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return fail(schema_version, "INVALID_REQUEST", "Invalid JSON body", 400);
  }

  const leave_type = String(body.leave_type ?? "").trim();
  const requested_employee_id = String(body.employee_id ?? "").trim() || null;
  const start_at = parse_timestamp(body.start_at);
  const end_at = parse_timestamp(body.end_at);
  const reason = String(body.reason ?? "").trim();

  if (!leave_type || !start_at || !end_at) {
    return fail(schema_version, "INVALID_REQUEST", "employee_id or resolvable employee, leave_type, start_at, end_at are required", 400);
  }

  const { data: employees, error: employees_error } = await list_leave_scoped_employees(service, scope);
  if (employees_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve scoped employees", 500);
  }

  const employee = resolve_leave_request_employee(employees, requested_employee_id, ctx.user_email);
  if (!employee) {
    return fail(
      schema_version,
      "EMPLOYEE_NOT_FOUND",
      "Failed to resolve leave requester within the selected context",
      400
    );
  }

  const employee_map = new Map(employees.map((item) => [item.id, item] as const));
  const { chain, broken_manager_employee_id } = build_approval_chain(employee, employee_map);
  if (broken_manager_employee_id) {
    return fail(
      schema_version,
      "MANAGER_CHAIN_BROKEN",
      "Failed to resolve full manager chain within the selected context",
      400,
      { manager_employee_id: broken_manager_employee_id }
    );
  }

  const insert_payload = {
    org_id: scope.org_id,
    company_id: scope.company_id,
    employee_id: employee.id,
    environment_type: scope.environment_type,
    is_demo: scope.is_demo,
    leave_type,
    start_date: iso_date(start_at),
    end_date: iso_date(end_at),
    start_time: iso_time(start_at),
    end_time: iso_time(end_at),
    start_at: start_at.toISOString(),
    end_at: end_at.toISOString(),
    reason,
    approval_status: "pending",
    status: "pending",
    current_step: 0,
    affects_payroll: false,
    has_attachment: false,
    attachment_count: 0,
    created_by: ctx.user_id,
    updated_by: ctx.user_id
  };

  const { data: leave_request, error: leave_error } = await service
    .from("leave_requests")
    .insert(insert_payload)
    .select("id,status,current_step")
    .maybeSingle();

  if (leave_error || !leave_request) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create leave request", 500);
  }

  if (chain.length > 0) {
    const approval_steps = chain.map((manager, index) => ({
      request_id: leave_request.id,
      step_order: index,
      approver_employee_id: manager.id,
      status: "pending"
    }));

    const { error: steps_error } = await service.from("leave_approval_steps").insert(approval_steps);
    if (steps_error) {
      return fail(schema_version, "INTERNAL_ERROR", "Failed to create leave approval steps", 500);
    }
  }

  const locale_hint = await resolve_leave_locale_hint(service, scope, employee, ctx.user_id);

  return ok(
    schema_version,
    {
      id: leave_request.id,
      status: leave_request.status ?? "pending",
      current_step: leave_request.current_step ?? 0,
      approval_steps_count: chain.length,
      resolved_locale: locale_hint.resolved_locale,
      locale_source: locale_hint.locale_source
    },
    201
  );
}

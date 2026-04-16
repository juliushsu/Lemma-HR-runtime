import {
  get_leave_read_context,
  get_leave_write_context,
  get_pagination_from_request,
  map_leave_rpc_error,
  normalize_leave_list_row,
  ok_with_meta
} from "../_lib";

export async function GET(request: Request) {
  const schema_version = "hr.leave.request.list.v1";
  const { response, ctx, scope } = await get_leave_read_context(request);
  if (response || !ctx || !scope) return response;

  const { data, error } = await ctx.supabase.rpc("list_leave_requests", {
    p_org_id: scope.org_id,
    p_company_id: scope.company_id
  });

  if (error) {
    return map_leave_rpc_error(schema_version, error, "Failed to fetch leave requests");
  }

  const url = new URL(request.url);
  const approval_status = url.searchParams.get("approval_status");
  const employee_id = url.searchParams.get("employee_id");
  const keyword = (url.searchParams.get("keyword") ?? "").trim().toLowerCase();
  const { page, page_size, from, to } = get_pagination_from_request(request);

  let items = (data ?? []).map(normalize_leave_list_row);

  if (approval_status) items = items.filter((item) => item.approval_status === approval_status);
  if (employee_id) items = items.filter((item) => item.employee_id === employee_id);
  if (keyword) {
    items = items.filter((item) => {
      const haystack = [
        item.employee_code,
        item.employee_display_name,
        item.leave_type,
        item.reason
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(keyword);
    });
  }

  const total = items.length;
  const paged = items.slice(from, to + 1);

  return ok_with_meta(schema_version, {
    items: paged,
    pagination: {
      page,
      page_size,
      total
    },
    scope: {
      org_id: scope.org_id,
      company_id: scope.company_id,
      environment_type: scope.environment_type
    }
  });
}

export async function POST(request: Request) {
  const schema_version = "hr.leave.request.create.v1";
  const { response, ctx, scope } = await get_leave_write_context(request);
  if (response || !ctx || !scope) return response;

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return map_leave_rpc_error(schema_version, { message: "INVALID_JSON_BODY" }, "Invalid JSON body");
  }

  const payload = {
    ...body,
    org_id: scope.org_id,
    company_id: scope.company_id,
    environment_type: scope.environment_type,
    is_demo: scope.is_demo,
    actor_user_id: ctx.user_id
  };

  const { data, error } = await ctx.supabase.rpc("create_leave_request", {
    p_payload: payload
  });

  if (error) {
    return map_leave_rpc_error(schema_version, error, "Failed to create leave request");
  }

  return ok_with_meta(schema_version, {
    leave_request: data
  }, 201);
}

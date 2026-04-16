import { fail, local_date_in_timezone, ok } from "../../../hr/_lib";
import { get_service_supabase, haversine_distance_m, line_bot_reply, resolve_line_locale } from "../_lib";
import { resolve_attendance_boundary } from "../../../hr/attendance/_boundary";
import { featureNotEnabledResponse, resolveFeatureAccess } from "../../../../lib/featureGating";

const CHECK_TYPES = new Set(["check_in", "check_out"]);

async function write_event_log(service: any, payload: Record<string, unknown>) {
  await service.from("line_webhook_event_logs").insert(payload);
}

export async function POST(request: Request) {
  const schema_version = "integration.line.webhook.v1";
  const feature_key = "attendance.line_checkin";
  const body = (await request.json()) as Record<string, unknown>;

  const event_id = body.event_id ? String(body.event_id) : null;
  const line_user_id = String(body.line_user_id ?? "");
  const check_type = String(body.check_type ?? "");
  const checked_at_raw = String(body.checked_at ?? new Date().toISOString());
  const source_ref = body.source_ref ? String(body.source_ref) : event_id;
  const gps_lat = body.gps_lat === null || body.gps_lat === undefined ? null : Number(body.gps_lat);
  const gps_lng = body.gps_lng === null || body.gps_lng === undefined ? null : Number(body.gps_lng);
  const requested_locale = body.locale ? String(body.locale) : null;

  if (!line_user_id || !check_type) {
    return fail(schema_version, "INVALID_REQUEST", "line_user_id and check_type are required", 400);
  }
  if (!CHECK_TYPES.has(check_type)) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid check_type", 400);
  }

  const checked_at = new Date(checked_at_raw);
  if (Number.isNaN(checked_at.getTime())) {
    return fail(schema_version, "INVALID_REQUEST", "Invalid checked_at", 400);
  }

  const service = get_service_supabase();
  if (!service) return fail(schema_version, "INTERNAL_ERROR", "Missing service role configuration", 500);

  const { data: binding, error: binding_error } = await service
    .from("line_bindings")
    .select("id,org_id,company_id,branch_id,environment_type,is_demo,user_id,employee_id,bind_status")
    .eq("line_user_id", line_user_id)
    .eq("bind_status", "active")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (binding_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to resolve line binding", 500);
  if (!binding) {
    const { data: latest_binding } = await service
      .from("line_bindings")
      .select("org_id,company_id,branch_id,environment_type,is_demo")
      .eq("line_user_id", line_user_id)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (latest_binding?.org_id) {
      const feature_access = await resolveFeatureAccess({
        org_id: String(latest_binding.org_id),
        feature_key
      });
      if (!feature_access.enabled) {
        return featureNotEnabledResponse(feature_key, 403);
      }
    }

    const locale_info = resolve_line_locale({
      payload_locale: requested_locale,
      accept_language: request.headers.get("accept-language")
    });
    const bot_reply = line_bot_reply("line.attendance.unbound", locale_info.locale, {
      requested_locale: locale_info.requested_locale
    });
    await write_event_log(service, {
      org_id: latest_binding?.org_id ?? null,
      company_id: latest_binding?.company_id ?? null,
      branch_id: latest_binding?.branch_id ?? null,
      environment_type: latest_binding?.environment_type ?? null,
      is_demo: latest_binding?.is_demo ?? null,
      line_user_id,
      event_id,
      event_type: "attendance.check",
      request_payload: body,
      decision_code: "LINE_IDENTITY_NOT_BOUND",
      decision_message: bot_reply.message
    });
    return fail(schema_version, "LINE_IDENTITY_NOT_BOUND", "LINE identity is not bound", 422, {
      bot_reply
    });
  }

  const scope = {
    org_id: binding.org_id,
    company_id: binding.company_id,
    environment_type: binding.environment_type
  };

  const feature_access = await resolveFeatureAccess({
    org_id: String(scope.org_id),
    feature_key
  });
  if (!feature_access.enabled) {
    return featureNotEnabledResponse(feature_key, 403);
  }

  const { data: employee, error: employee_error } = await service
    .from("employees")
    .select("id,branch_id,timezone,preferred_locale")
    .eq("id", binding.employee_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .maybeSingle();

  if (employee_error) return fail(schema_version, "INTERNAL_ERROR", "Failed to fetch employee", 500);
  if (!employee) return fail(schema_version, "EMPLOYEE_NOT_FOUND", "Employee not found", 404);

  const { data: assignment } = await service
    .from("employee_assignments")
    .select("branch_id,effective_from")
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .eq("employee_id", employee.id)
    .eq("is_current", true)
    .order("effective_from", { ascending: false })
    .limit(1)
    .maybeSingle();

  const resolved_branch_id = employee.branch_id ?? assignment?.branch_id ?? null;

  const [{ data: branch }, { data: company_settings }, { data: boundaries }] = await Promise.all([
    resolved_branch_id
      ? service
          .from("branches")
          .select("id,name,latitude,longitude,is_attendance_enabled")
          .eq("id", resolved_branch_id)
          .eq("org_id", scope.org_id)
          .eq("company_id", scope.company_id)
          .eq("environment_type", scope.environment_type)
          .maybeSingle()
      : Promise.resolve({ data: null }),
    service
      .from("company_settings")
      .select("is_attendance_enabled,default_locale")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .eq("environment_type", scope.environment_type)
      .maybeSingle(),
    service
      .from("attendance_boundary_settings")
      .select("branch_id,checkin_radius_m,is_attendance_enabled")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .eq("environment_type", scope.environment_type)
  ]);

  const { data: user_row } = binding.user_id
    ? await service
        .from("users")
        .select("locale_preference")
        .eq("id", binding.user_id)
        .maybeSingle()
    : { data: null };
  const locale_info = resolve_line_locale({
    payload_locale: requested_locale,
    accept_language: request.headers.get("accept-language"),
    employee_locale: employee.preferred_locale,
    user_locale: user_row?.locale_preference ?? null,
    company_default_locale: company_settings?.default_locale ?? null
  });

  const resolved_boundary = resolve_attendance_boundary({
    boundaries,
    resolved_branch_id,
    location_is_attendance_enabled: branch?.is_attendance_enabled ?? null,
    company_is_attendance_enabled: company_settings?.is_attendance_enabled ?? null
  });

  if (!resolved_boundary.is_attendance_enabled) {
    const bot_reply = line_bot_reply("line.binding.failed", locale_info.locale, {
      requested_locale: locale_info.requested_locale
    });
    await write_event_log(service, {
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: resolved_branch_id,
      environment_type: scope.environment_type,
      is_demo: binding.is_demo,
      line_user_id,
      event_id,
      event_type: "attendance.check",
      source_ref,
      request_payload: body,
      decision_code: "ATTENDANCE_DISABLED",
      decision_message: bot_reply.message
    });
    return fail(schema_version, "ATTENDANCE_DISABLED", "Attendance is disabled", 422, {
      bot_reply
    });
  }

  if (source_ref) {
    const { data: existing_by_source } = await service
      .from("attendance_logs")
      .select("id")
      .eq("org_id", scope.org_id)
      .eq("company_id", scope.company_id)
      .eq("environment_type", scope.environment_type)
      .eq("employee_id", employee.id)
      .eq("source_type", "line")
      .eq("source_ref", source_ref)
      .maybeSingle();

    if (existing_by_source) {
      const bot_reply = line_bot_reply("line.attendance.duplicate", locale_info.locale, {
        requested_locale: locale_info.requested_locale
      });
      return ok(schema_version, {
        duplicate: true,
        attendance_log_id: existing_by_source.id,
        bot_reply
      });
    }
  }

  const { data: existing_by_time } = await service
    .from("attendance_logs")
    .select("id")
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .eq("employee_id", employee.id)
    .eq("check_type", check_type)
    .eq("checked_at", checked_at.toISOString())
    .maybeSingle();
  if (existing_by_time) {
    const bot_reply = line_bot_reply("line.attendance.duplicate", locale_info.locale, {
      requested_locale: locale_info.requested_locale
    });
    return ok(schema_version, {
      duplicate: true,
      attendance_log_id: existing_by_time.id,
      bot_reply
    });
  }

  let geo_distance_m: number | null = null;
  if (
    branch?.latitude !== null &&
    branch?.latitude !== undefined &&
    branch?.longitude !== null &&
    branch?.longitude !== undefined &&
    gps_lat !== null &&
    gps_lng !== null &&
    Number.isFinite(gps_lat) &&
    Number.isFinite(gps_lng)
  ) {
    geo_distance_m = Number(
      haversine_distance_m(
        Number(branch.latitude),
        Number(branch.longitude),
        Number(gps_lat),
        Number(gps_lng)
      ).toFixed(2)
    );
  }

  if (
    resolved_boundary.checkin_radius_m !== null &&
    resolved_boundary.checkin_radius_m !== undefined &&
    geo_distance_m !== null &&
    geo_distance_m > Number(resolved_boundary.checkin_radius_m)
  ) {
    const bot_reply = line_bot_reply("line.attendance.out_of_range", locale_info.locale, {
      requested_locale: locale_info.requested_locale
    });
    await write_event_log(service, {
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: resolved_branch_id,
      environment_type: scope.environment_type,
      is_demo: binding.is_demo,
      line_user_id,
      event_id,
      event_type: "attendance.check",
      source_ref,
      request_payload: body,
      decision_code: "OUT_OF_GEO_BOUNDARY",
      decision_message: bot_reply.message
    });
    return fail(schema_version, "OUT_OF_GEO_BOUNDARY", "Out of attendance boundary", 422, {
      geo_distance_m,
      checkin_radius_m: resolved_boundary.checkin_radius_m,
      bot_reply
    });
  }

  const { data: profile } = await service
    .from("employee_attendance_profiles")
    .select("attendance_policy_id")
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .eq("environment_type", scope.environment_type)
    .eq("employee_id", employee.id)
    .eq("is_current", true)
    .order("effective_from", { ascending: false })
    .limit(1)
    .maybeSingle();

  const { data: policy } = profile?.attendance_policy_id
    ? await service
        .from("attendance_policies")
        .select("timezone")
        .eq("org_id", scope.org_id)
        .eq("company_id", scope.company_id)
        .eq("environment_type", scope.environment_type)
        .eq("id", profile.attendance_policy_id)
        .maybeSingle()
    : { data: null };

  const timezone = policy?.timezone ?? employee.timezone ?? "Asia/Taipei";
  const attendance_date = local_date_in_timezone(checked_at.toISOString(), timezone);
  const is_within_geo_range =
    resolved_boundary.checkin_radius_m !== null &&
    resolved_boundary.checkin_radius_m !== undefined &&
    geo_distance_m !== null
      ? geo_distance_m <= Number(resolved_boundary.checkin_radius_m)
      : null;

  const nowIso = new Date().toISOString();
  const { data: created, error: create_error } = await service
    .from("attendance_logs")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: resolved_branch_id,
      environment_type: scope.environment_type,
      is_demo: binding.is_demo,
      employee_id: employee.id,
      attendance_date,
      check_type,
      checked_at: checked_at.toISOString(),
      source_type: "line",
      source_ref,
      gps_lat: Number.isFinite(gps_lat as number) ? gps_lat : null,
      gps_lng: Number.isFinite(gps_lng as number) ? gps_lng : null,
      geo_distance_m,
      is_within_geo_range,
      status_code: "normal",
      is_valid: true,
      is_adjusted: false,
      note: "LINE webhook check-in",
      created_by: binding.user_id,
      updated_by: binding.user_id
    })
    .select("id")
    .maybeSingle();

  if (create_error) {
    return fail(schema_version, "INTERNAL_ERROR", "Failed to create attendance log", 500);
  }

  await service
    .from("line_bindings")
    .update({ last_seen_at: nowIso, updated_at: nowIso })
    .eq("id", binding.id);

  await write_event_log(service, {
    org_id: scope.org_id,
    company_id: scope.company_id,
    branch_id: resolved_branch_id,
    environment_type: scope.environment_type,
    is_demo: binding.is_demo,
    line_user_id,
    event_id,
    event_type: "attendance.check",
    source_ref,
    request_payload: body,
    decision_code: "ACCEPTED",
    decision_message:
      check_type === "check_out"
        ? line_bot_reply("line.attendance.check_out.success", locale_info.locale).message
        : line_bot_reply("line.attendance.check_in.success", locale_info.locale).message,
    attendance_log_id: created?.id ?? null
  });

  const bot_reply =
    check_type === "check_out"
      ? line_bot_reply("line.attendance.check_out.success", locale_info.locale, {
          requested_locale: locale_info.requested_locale
        })
      : line_bot_reply("line.attendance.check_in.success", locale_info.locale, {
          requested_locale: locale_info.requested_locale
        });

  return ok(schema_version, {
    duplicate: false,
    attendance_log_id: created?.id ?? null,
    employee_id: employee.id,
    branch_id: resolved_branch_id,
    resolved_from: resolved_boundary.resolved_from,
    checkin_radius_m: resolved_boundary.checkin_radius_m ?? null,
    is_within_geo_range,
    bot_reply
  }, 201);
}

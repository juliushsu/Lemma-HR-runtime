import {
  get_scoped_context,
  success,
  failure,
  parse_json_body,
  to_number,
  haversine_distance_m
} from "../../_attendance_phase1";

const CHECK_TYPES = new Set(["check_in", "check_out"]);

function map_source_type(source_key: string) {
  if (source_key === "line_bot") return "line";
  if (source_key === "external_api") return "external_api";
  if (source_key === "timesheet_upload") return "manual_upload";
  if (source_key === "face_recognition") return "kiosk";
  if (source_key === "rfid") return "kiosk";
  return "manual";
}

function map_status_code(status_color: "green" | "yellow" | "orange") {
  if (status_color === "orange") return "missing";
  return "normal";
}

export async function POST(request: Request) {
  const rawBody = await request.text();
  const body = parse_json_body(rawBody);
  if (body === null) return failure("INVALID_JSON", "Request body must be valid JSON", 400);

  // Use read scope to keep employee-facing check-in compatible with existing role policy.
  const scoped = await get_scoped_context(request, { write: false, body });
  if (scoped.response) return scoped.response;

  const { ctx, scope } = scoped;

  const employee_id = typeof body.employee_id === "string" ? body.employee_id : "";
  const location_id = typeof body.location_id === "string" ? body.location_id : "";
  const attendance_source_id = typeof body.attendance_source_id === "string" ? body.attendance_source_id : null;
  const source_key_from_body = typeof body.source_key === "string" ? body.source_key : null;
  const check_type = typeof body.check_type === "string" ? body.check_type : "";
  const checked_at =
    typeof body.checked_at === "string" && body.checked_at.trim() ? body.checked_at : new Date().toISOString();

  if (!employee_id || !location_id || !check_type || (!attendance_source_id && !source_key_from_body)) {
    return failure(
      "INVALID_REQUEST",
      "employee_id, location_id, check_type, and attendance_source_id or source_key are required",
      400
    );
  }
  if (!CHECK_TYPES.has(check_type)) {
    return failure("INVALID_CHECK_TYPE", "check_type must be check_in or check_out", 400);
  }

  const { data: employee, error: employee_error } = await ctx.supabase
    .from("employees")
    .select("id")
    .eq("id", employee_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .maybeSingle();
  if (employee_error) return failure("INTERNAL_ERROR", "Failed to verify employee", 500);
  if (!employee) return failure("EMPLOYEE_NOT_FOUND", "Employee not found in current scope", 404);

  const { data: location, error: location_error } = await ctx.supabase
    .from("locations")
    .select("id,name,latitude,longitude,checkin_radius_m,is_attendance_enabled")
    .eq("id", location_id)
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id)
    .maybeSingle();
  if (location_error) return failure("INTERNAL_ERROR", "Failed to verify location", 500);
  if (!location) return failure("LOCATION_NOT_FOUND", "Location not found in current scope", 404);
  if (location.is_attendance_enabled === false) {
    return failure("LOCATION_ATTENDANCE_DISABLED", "Attendance is disabled on this location", 422);
  }

  let sourceQuery = ctx.supabase
    .from("attendance_sources")
    .select("id,source_key,is_enabled,config")
    .eq("org_id", scope.org_id)
    .eq("company_id", scope.company_id);

  if (attendance_source_id) sourceQuery = sourceQuery.eq("id", attendance_source_id);
  if (!attendance_source_id && source_key_from_body) sourceQuery = sourceQuery.eq("source_key", source_key_from_body);

  const { data: source, error: source_error } = await sourceQuery.maybeSingle();
  if (source_error) return failure("INTERNAL_ERROR", "Failed to verify attendance source", 500);
  if (!source) return failure("ATTENDANCE_SOURCE_NOT_FOUND", "Attendance source not found in current scope", 404);
  if (source.is_enabled !== true) {
    return failure("ATTENDANCE_SOURCE_DISABLED", "Attendance source is disabled", 422);
  }
  if (source_key_from_body && source_key_from_body !== source.source_key) {
    return failure("INVALID_REQUEST", "source_key does not match attendance_source_id", 400);
  }

  const gps_latitude = to_number(body.gps_latitude ?? body.latitude);
  const gps_longitude = to_number(body.gps_longitude ?? body.longitude);
  const location_latitude = to_number(location.latitude);
  const location_longitude = to_number(location.longitude);

  let distance_m: number | null = null;
  let is_within_range: boolean | null = null;
  let status_color: "green" | "yellow" | "orange" = "orange";

  const has_gps_inputs =
    gps_latitude !== null &&
    gps_longitude !== null &&
    location_latitude !== null &&
    location_longitude !== null;

  if (has_gps_inputs) {
    const rawDistance = haversine_distance_m(gps_latitude!, gps_longitude!, location_latitude!, location_longitude!);
    distance_m = Math.round(rawDistance * 100) / 100;

    if (typeof location.checkin_radius_m === "number") {
      is_within_range = distance_m <= location.checkin_radius_m;
      status_color = is_within_range ? "green" : "yellow";
    } else {
      status_color = "yellow";
    }
  }

  const raw_payload = {
    request_payload: body,
    computed: {
      distance_m,
      is_within_range,
      status_color
    },
    location_snapshot: {
      id: location.id,
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
      checkin_radius_m: location.checkin_radius_m
    },
    source_snapshot: {
      id: source.id,
      source_key: source.source_key,
      is_enabled: source.is_enabled
    }
  };

  const notes = typeof body.notes === "string" ? body.notes : null;
  const source_type = map_source_type(source.source_key);
  const status_code = map_status_code(status_color);
  const attendance_date = checked_at.slice(0, 10);

  const { data: created, error: create_error } = await ctx.supabase
    .from("attendance_logs")
    .insert({
      org_id: scope.org_id,
      company_id: scope.company_id,
      branch_id: scope.branch_id,
      environment_type: scope.environment_type,
      is_demo: scope.is_demo,
      employee_id,
      attendance_date,
      location_id: location.id,
      attendance_source_id: source.id,
      source_key: source.source_key,
      source_type,
      check_type,
      checked_at,
      gps_lat: gps_latitude,
      gps_lng: gps_longitude,
      gps_latitude,
      gps_longitude,
      geo_distance_m: distance_m,
      distance_m,
      is_within_geo_range: is_within_range,
      is_within_range,
      record_source: "system",
      status_code,
      status_color,
      is_valid: true,
      is_adjusted: false,
      note: notes,
      raw_payload,
      notes
    })
    .select(
      "id,org_id,company_id,employee_id,location_id,attendance_source_id,source_key,check_type,checked_at,gps_latitude,gps_longitude,distance_m,is_within_range,status_color,is_valid,record_source,raw_payload,notes,created_at,updated_at"
    )
    .maybeSingle();

  if (create_error) {
    return failure("INTERNAL_ERROR", "Failed to create attendance log", 500, { detail: create_error.message });
  }

  return success(
    {
      item: created,
      rule_result: {
        source_enabled: true,
        location_valid: true,
        distance_m,
        is_within_range,
        status_color
      }
    },
    201
  );
}

import { createClient } from "@supabase/supabase-js";
import { createHmac, timingSafeEqual } from "node:crypto";
import { parse_attendance_date, parse_check_type, parse_datetime_iso } from "../imports/_lib";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

export type ExternalSource = {
  id: string;
  org_id: string;
  company_id: string;
  branch_id: string | null;
  environment_type: string;
  is_demo: boolean;
  source_type: "external_api";
  source_key: string;
  source_name: string;
  auth_mode: "hmac_sha256" | "bearer_token";
  credential: string;
  config_json: Record<string, unknown> | null;
  is_enabled: boolean;
};

export type ExternalEventInput = {
  event_id?: string | null;
  source_ref?: string | null;
  employee_code?: string | null;
  external_employee_ref?: string | null;
  attendance_date?: string | null;
  check_type?: string | null;
  checked_at?: string | null;
  branch_id?: string | null;
  branch_ref?: string | null;
  note?: string | null;
  [key: string]: unknown;
};

export type NormalizedExternalEvent = {
  row_index: number;
  event_id: string | null;
  source_ref: string | null;
  employee_code: string | null;
  external_employee_ref: string | null;
  attendance_date: string | null;
  check_type: "check_in" | "check_out" | null;
  checked_at: string | null;
  branch_id: string | null;
  parsed_payload: Record<string, unknown>;
};

export function get_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

function strip_header_prefix(value: string) {
  return value.replace(/^sha256=/i, "").trim();
}

export function verify_hmac_signature(raw_body: string, secret: string, provided_signature: string | null) {
  if (!provided_signature || !secret) return false;
  const expected = createHmac("sha256", secret).update(raw_body).digest("hex");
  const expected_buf = Buffer.from(expected);
  const provided_buf = Buffer.from(strip_header_prefix(provided_signature));
  if (expected_buf.length !== provided_buf.length) return false;
  return timingSafeEqual(expected_buf, provided_buf);
}

export function verify_bearer_token(authorization_header: string | null, expected_token: string) {
  if (!authorization_header || !expected_token) return false;
  if (!authorization_header.startsWith("Bearer ")) return false;
  const incoming = authorization_header.slice(7).trim();
  const expected_buf = Buffer.from(expected_token);
  const incoming_buf = Buffer.from(incoming);
  if (expected_buf.length !== incoming_buf.length) return false;
  return timingSafeEqual(expected_buf, incoming_buf);
}

export function parse_inbound_events(payload: unknown): ExternalEventInput[] {
  if (!payload || typeof payload !== "object") return [];
  const body = payload as Record<string, unknown>;
  const events = body.events;
  if (Array.isArray(events)) {
    return events.filter((item): item is ExternalEventInput => !!item && typeof item === "object");
  }
  return [body as ExternalEventInput];
}

export function normalize_event_input(row_index: number, event: ExternalEventInput): NormalizedExternalEvent {
  const event_id = event.event_id ? String(event.event_id).trim() : null;
  const source_ref = event.source_ref ? String(event.source_ref).trim() : null;
  const employee_code = event.employee_code ? String(event.employee_code).trim() : null;
  const external_employee_ref = event.external_employee_ref ? String(event.external_employee_ref).trim() : null;
  const checked_at = parse_datetime_iso(event.checked_at ? String(event.checked_at).trim() : null);
  const attendance_date = parse_attendance_date(
    event.attendance_date ? String(event.attendance_date).trim() : null,
    checked_at
  );
  const check_type = parse_check_type(event.check_type ? String(event.check_type).trim() : null);
  const branch_id = event.branch_id ? String(event.branch_id).trim() : null;

  return {
    row_index,
    event_id,
    source_ref,
    employee_code,
    external_employee_ref,
    attendance_date,
    check_type,
    checked_at,
    branch_id,
    parsed_payload: event as Record<string, unknown>
  };
}

export function get_string_map(input: unknown): Record<string, string> {
  if (!input || typeof input !== "object" || Array.isArray(input)) return {};
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(input as Record<string, unknown>)) {
    if (value === null || value === undefined) continue;
    const normalized_key = String(key).trim();
    const normalized_value = String(value).trim();
    if (normalized_key && normalized_value) out[normalized_key] = normalized_value;
  }
  return out;
}

export function resolve_event_source_ref(event_id: string | null, source_ref: string | null) {
  return source_ref || event_id || null;
}


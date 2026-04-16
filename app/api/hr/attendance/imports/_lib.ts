import { createClient } from "@supabase/supabase-js";
import * as XLSX from "xlsx";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

export type ManualUploadFileType = "csv" | "xlsx";

export type ParsedUploadRow = {
  row_index: number;
  employee_code: string | null;
  attendance_date: string | null;
  check_type: string | null;
  checked_at: string | null;
  branch_id: string | null;
  branch_name: string | null;
  raw: Record<string, unknown>;
};

const EMPLOYEE_CODE_ALIASES = ["employee_code", "employee code", "emp_code", "code", "員工編號"];
const ATTENDANCE_DATE_ALIASES = ["attendance_date", "attendance date", "date", "日期"];
const CHECK_TYPE_ALIASES = ["check_type", "check type", "type", "in_out", "in/out", "打卡類型"];
const CHECKED_AT_ALIASES = ["checked_at", "checked at", "datetime", "timestamp", "打卡時間"];
const BRANCH_ID_ALIASES = ["branch_id", "branch id"];
const BRANCH_NAME_ALIASES = ["branch_name", "branch name", "location_name", "location name", "branch", "分店"];

function norm_key(key: string) {
  return key.trim().toLowerCase().replace(/\s+/g, "_");
}

function normalize_row(raw: Record<string, unknown>) {
  const out = new Map<string, unknown>();
  for (const [k, v] of Object.entries(raw)) out.set(norm_key(k), v);
  return out;
}

function pick_value(normalized: Map<string, unknown>, aliases: string[]) {
  for (const alias of aliases) {
    const value = normalized.get(norm_key(alias));
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      return String(value).trim();
    }
  }
  return null;
}

export function get_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

export function detect_file_type(file_name: string): ManualUploadFileType | null {
  const lower = file_name.toLowerCase();
  if (lower.endsWith(".csv")) return "csv";
  if (lower.endsWith(".xlsx")) return "xlsx";
  return null;
}

export function parse_check_type(input: string | null): "check_in" | "check_out" | null {
  if (!input) return null;
  const v = input.trim().toLowerCase();
  if (v === "check_in" || v === "check-in" || v === "in" || v === "上班") return "check_in";
  if (v === "check_out" || v === "check-out" || v === "out" || v === "下班") return "check_out";
  return null;
}

export function parse_datetime_iso(input: string | null): string | null {
  if (!input) return null;
  const dt = new Date(input);
  if (Number.isNaN(dt.getTime())) return null;
  return dt.toISOString();
}

export function parse_attendance_date(input: string | null, checked_at_iso: string | null): string | null {
  if (input) {
    const d = new Date(input);
    if (!Number.isNaN(d.getTime())) return d.toISOString().slice(0, 10);
    return null;
  }
  if (!checked_at_iso) return null;
  return checked_at_iso.slice(0, 10);
}

export function parse_upload_file(buffer: Buffer): ParsedUploadRow[] {
  const workbook = XLSX.read(buffer, { type: "buffer", cellDates: false, raw: false });
  const first_sheet = workbook.SheetNames[0];
  if (!first_sheet) return [];

  const sheet = workbook.Sheets[first_sheet];
  const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(sheet, {
    defval: null,
    raw: false
  });

  return rows.map((raw, idx) => {
    const normalized = normalize_row(raw);
    return {
      row_index: idx + 1,
      employee_code: pick_value(normalized, EMPLOYEE_CODE_ALIASES),
      attendance_date: pick_value(normalized, ATTENDANCE_DATE_ALIASES),
      check_type: pick_value(normalized, CHECK_TYPE_ALIASES),
      checked_at: pick_value(normalized, CHECKED_AT_ALIASES),
      branch_id: pick_value(normalized, BRANCH_ID_ALIASES),
      branch_name: pick_value(normalized, BRANCH_NAME_ALIASES),
      raw
    };
  });
}

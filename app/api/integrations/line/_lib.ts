import { createClient } from "@supabase/supabase-js";
import { createHash, randomBytes } from "node:crypto";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

export function get_service_supabase() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

export function issue_plain_token() {
  return randomBytes(24).toString("base64url");
}

export function hash_token(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

export function token_last4(token: string) {
  return token.slice(-4);
}

export const LINE_MVP_SUPPORTED_LOCALES = ["zh-TW", "en", "ja", "ko"] as const;
export const LINE_PHASE_1_1_RESERVED_LOCALES = ["th", "vi", "id"] as const;

export type LineMvpLocale = (typeof LINE_MVP_SUPPORTED_LOCALES)[number];
type LineMessageKey =
  | "line.binding.success"
  | "line.binding.failed"
  | "line.attendance.check_in.success"
  | "line.attendance.check_out.success"
  | "line.attendance.duplicate"
  | "line.attendance.out_of_range"
  | "line.attendance.unbound";

const LINE_MESSAGES: Record<LineMessageKey, Record<LineMvpLocale, string>> = {
  "line.binding.success": {
    "zh-TW": "綁定成功，之後可直接用 LINE 打卡。",
    en: "Binding successful. You can now check in via LINE.",
    ja: "連携に成功しました。今後はLINEで打刻できます。",
    ko: "연동이 완료되었습니다. 이제 LINE으로 출퇴근 기록이 가능합니다."
  },
  "line.binding.failed": {
    "zh-TW": "綁定失敗，請重新取得綁定連結後再試一次。",
    en: "Binding failed. Please generate a new binding link and try again.",
    ja: "連携に失敗しました。新しい連携リンクで再試行してください。",
    ko: "연동에 실패했습니다. 새 연동 링크로 다시 시도해 주세요."
  },
  "line.attendance.check_in.success": {
    "zh-TW": "上班打卡成功。",
    en: "Check-in successful.",
    ja: "出勤打刻が完了しました。",
    ko: "출근 기록이 완료되었습니다."
  },
  "line.attendance.check_out.success": {
    "zh-TW": "下班打卡成功。",
    en: "Check-out successful.",
    ja: "退勤打刻が完了しました。",
    ko: "퇴근 기록이 완료되었습니다."
  },
  "line.attendance.duplicate": {
    "zh-TW": "重複打卡，系統已忽略重複請求。",
    en: "Duplicate check detected. The duplicate request was ignored.",
    ja: "重複打刻が検出されました。重複リクエストは無視されました。",
    ko: "중복 기록이 감지되어 중복 요청은 무시되었습니다."
  },
  "line.attendance.out_of_range": {
    "zh-TW": "超出打卡範圍，請在允許範圍內再試一次。",
    en: "You are outside the allowed attendance boundary. Please try again within range.",
    ja: "打刻可能範囲外です。範囲内で再度お試しください。",
    ko: "허용된 출퇴근 범위를 벗어났습니다. 범위 내에서 다시 시도해 주세요."
  },
  "line.attendance.unbound": {
    "zh-TW": "尚未完成綁定，請先使用綁定連結完成設定。",
    en: "Your LINE account is not bound yet. Please complete binding first.",
    ja: "まだ連携が完了していません。先に連携を完了してください。",
    ko: "아직 연동되지 않았습니다. 먼저 연동을 완료해 주세요."
  }
};

function normalize_locale(input: string | null | undefined): string | null {
  if (!input) return null;
  const raw = input.trim();
  if (!raw) return null;
  const normalized = raw.toLowerCase().replace("_", "-");
  if (normalized === "zh-tw" || normalized === "zh-hant") return "zh-TW";
  if (normalized.startsWith("zh-tw")) return "zh-TW";
  if (normalized === "en" || normalized.startsWith("en-")) return "en";
  if (normalized === "ja" || normalized.startsWith("ja-")) return "ja";
  if (normalized === "ko" || normalized.startsWith("ko-")) return "ko";
  if (normalized === "th" || normalized.startsWith("th-")) return "th";
  if (normalized === "vi" || normalized.startsWith("vi-")) return "vi";
  if (normalized === "id" || normalized.startsWith("id-")) return "id";
  return null;
}

export function resolve_line_locale(params: {
  payload_locale?: string | null;
  accept_language?: string | null;
  binding_locale?: string | null;
  employee_locale?: string | null;
  user_locale?: string | null;
  company_default_locale?: string | null;
}) {
  const requested =
    normalize_locale(params.payload_locale) ??
    normalize_locale(params.accept_language?.split(",")[0] ?? null) ??
    normalize_locale(params.binding_locale) ??
    normalize_locale(params.employee_locale) ??
    normalize_locale(params.user_locale) ??
    normalize_locale(params.company_default_locale) ??
    "en";

  const locale = (LINE_MVP_SUPPORTED_LOCALES as readonly string[]).includes(requested) ? requested : "en";
  const is_phase_1_1_requested = (LINE_PHASE_1_1_RESERVED_LOCALES as readonly string[]).includes(requested);

  return {
    locale: locale as LineMvpLocale,
    requested_locale: requested,
    is_phase_1_1_requested
  };
}

export function line_message(key: LineMessageKey, locale: LineMvpLocale) {
  return LINE_MESSAGES[key][locale] ?? LINE_MESSAGES[key].en;
}

export function line_bot_reply(
  key: LineMessageKey,
  locale: LineMvpLocale,
  extras: Record<string, unknown> = {}
) {
  return {
    locale,
    message_key: key,
    message: line_message(key, locale),
    supported_locales: [...LINE_MVP_SUPPORTED_LOCALES],
    phase_1_1_reserved_locales: [...LINE_PHASE_1_1_RESERVED_LOCALES],
    ...extras
  };
}

export function haversine_distance_m(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
) {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

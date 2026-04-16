import { apply_scope } from "../_lib";

export type LeaveScopedEmployee = {
  id: string;
  employee_code: string;
  legal_name: string | null;
  work_email: string | null;
  personal_email: string | null;
  manager_employee_id: string | null;
  preferred_locale: string | null;
};

export type LeaveLocaleHint = {
  resolved_locale: string;
  locale_source:
    | "employee.preferred_locale"
    | "user.locale_preference"
    | "company.locale_default"
    | "org.locale_default"
    | "fallback.en";
};

const SUPPORTED_EMPLOYEE_LOCALES = new Set([
  "zh-TW",
  "en",
  "ja",
  "th",
  "vi",
  "id",
  "tl",
  "my",
  "hi"
]);

export async function list_leave_scoped_employees(service: any, scope: any) {
  let query = apply_scope(
    service
      .from("employees")
      .select("id,employee_code,legal_name,work_email,personal_email,manager_employee_id,preferred_locale"),
    scope
  );

  if (scope.branch_id) {
    query = query.eq("branch_id", scope.branch_id);
  }

  const { data, error } = await query.order("employee_code", { ascending: true });
  return { data: (data ?? []) as LeaveScopedEmployee[], error };
}

export function resolve_leave_request_employee(
  employees: LeaveScopedEmployee[],
  requested_employee_id: string | null,
  user_email: string | null
) {
  if (requested_employee_id) {
    return employees.find((employee) => employee.id === requested_employee_id) ?? null;
  }

  const normalizedEmail = (user_email ?? "").trim().toLowerCase();
  if (!normalizedEmail) return null;

  return (
    employees.find((employee) => {
      const work = (employee.work_email ?? "").trim().toLowerCase();
      const personal = (employee.personal_email ?? "").trim().toLowerCase();
      return work === normalizedEmail || personal === normalizedEmail;
    }) ?? null
  );
}

export function normalize_leave_locale(value: unknown) {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  return SUPPORTED_EMPLOYEE_LOCALES.has(raw) ? raw : null;
}

export async function resolve_leave_locale_hint(
  service: any,
  scope: any,
  employee: LeaveScopedEmployee | null,
  user_id: string
): Promise<LeaveLocaleHint> {
  const employee_locale = normalize_leave_locale(employee?.preferred_locale);
  if (employee_locale) {
    return {
      resolved_locale: employee_locale,
      locale_source: "employee.preferred_locale"
    };
  }

  const [{ data: user }, { data: company }, { data: org }] = await Promise.all([
    service.from("users").select("locale_preference").eq("id", user_id).maybeSingle(),
    service.from("companies").select("locale_default").eq("id", scope.company_id).maybeSingle(),
    service.from("organizations").select("locale_default").eq("id", scope.org_id).maybeSingle()
  ]);

  const user_locale = normalize_leave_locale(user?.locale_preference);
  if (user_locale) {
    return {
      resolved_locale: user_locale,
      locale_source: "user.locale_preference"
    };
  }

  const company_locale = normalize_leave_locale(company?.locale_default);
  if (company_locale) {
    return {
      resolved_locale: company_locale,
      locale_source: "company.locale_default"
    };
  }

  const org_locale = normalize_leave_locale(org?.locale_default);
  if (org_locale) {
    return {
      resolved_locale: org_locale,
      locale_source: "org.locale_default"
    };
  }

  return {
    resolved_locale: "en",
    locale_source: "fallback.en"
  };
}

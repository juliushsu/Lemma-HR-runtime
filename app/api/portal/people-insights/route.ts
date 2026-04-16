import { compute_people_insights, ensure_portal_access, is_departed_status, load_people_base, ok } from "../_lib";

export async function GET(request: Request) {
  const schema_version = "portal.people_insights.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const loaded = await load_people_base(access.ctx, access.scope);
  if (loaded.error) return loaded.error;

  const insights = compute_people_insights(loaded.employees);
  const department_name_by_id = new Map<string, string>(
    loaded.departments.map((d: any) => [String(d.id), String(d.department_name ?? "Unassigned")])
  );
  const headcount_distribution = insights.headcount_distribution ?? {};
  const headcount_distribution_items = Object.entries(headcount_distribution as Record<string, number>).map(([status, count]) => ({
    status,
    count
  }));
  const employment_type_distribution: Record<string, number> = {};
  const department_distribution_map = new Map<string, { department_id: string | null; department_name: string; count: number }>();
  for (const e of loaded.employees) {
    const employment_type = String(e.employment_type ?? "unknown");
    employment_type_distribution[employment_type] = (employment_type_distribution[employment_type] ?? 0) + 1;

    const department_id = e.department_id ? String(e.department_id) : null;
    const map_key = department_id ?? "__unassigned__";
    const existing = department_distribution_map.get(map_key);
    if (existing) {
      existing.count += 1;
    } else {
      department_distribution_map.set(map_key, {
        department_id,
        department_name: department_id ? (department_name_by_id.get(department_id) ?? "Unknown Department") : "Unassigned",
        count: 1
      });
    }
  }
  const department_distribution = Array.from(department_distribution_map.values()).sort((a, b) => b.count - a.count);
  const employment_type_distribution_items = Object.entries(employment_type_distribution as Record<string, number>)
    .map(([employment_type, count]) => ({ employment_type, count }))
    .sort((a, b) => b.count - a.count);
  const data_completeness = insights.data_completeness ?? {
    score: 0,
    complete_count: 0,
    total_count: 0,
    missing_fields: {
      full_name_local: 0,
      department_id: 0,
      position_id: 0,
      hire_date: 0,
      employment_status: 0
    }
  };
  const new_hires_count = Number(insights.new_hires_count ?? 0);
  const departures_count = Number(insights.departures_count ?? 0);
  const total_employee_count = loaded.employees.length;
  const active_employee_count = loaded.employees.filter((e: any) => !is_departed_status(e.employment_status)).length;
  const terminated_employee_count = loaded.employees.filter((e: any) => is_departed_status(e.employment_status)).length;
  const new_hire_examples = loaded.employees
    .filter((e: any) => {
      if (!e.hire_date) return false;
      const hire = new Date(e.hire_date).getTime();
      if (Number.isNaN(hire)) return false;
      const now = Date.now();
      const in30days = 30 * 24 * 60 * 60 * 1000;
      return hire <= now && now - hire <= in30days;
    })
    .sort((a: any, b: any) => String(b.hire_date ?? "").localeCompare(String(a.hire_date ?? "")))
    .slice(0, 5)
    .map((e: any) => ({
      employee_code: e.employee_code ?? e.id,
      employee_name: e.full_name_local ?? e.full_name_latin ?? e.display_name ?? "Unknown",
      hire_date: e.hire_date ?? null
    }));
  const departure_examples = loaded.employees
    .filter((e: any) => is_departed_status(e.employment_status))
    .slice(0, 5)
    .map((e: any) => ({
      employee_code: e.employee_code ?? e.id,
      employee_name: e.full_name_local ?? e.full_name_latin ?? e.display_name ?? "Unknown",
      employment_status: e.employment_status ?? null
    }));

  return ok(schema_version, {
    org_id: access.scope.org_id,
    company_id: access.scope.company_id,
    summary: {
      total_employee_count,
      active_employee_count,
      terminated_employee_count,
      departures_count,
      new_hires_count,
      data_completeness_score: data_completeness.score
    },
    headcount_distribution,
    headcount_distribution_items,
    department_distribution,
    employment_type_distribution,
    employment_type_distribution_items,
    new_hires_count,
    departures_count,
    new_hire_examples,
    departure_examples,
    data_completeness,
    narrative_summary: {
      active_employee_count,
      terminated_employee_count,
      new_hires_count,
      departures_count,
      top_department: department_distribution[0] ?? null,
      top_employment_type: employment_type_distribution_items[0] ?? null,
      data_completeness_score: data_completeness.score
    },
    // camelCase aliases for frontend adapters that normalize DTO keys on the client side.
    summaryData: {
      totalEmployeeCount: total_employee_count,
      activeEmployeeCount: active_employee_count,
      terminatedEmployeeCount: terminated_employee_count,
      departuresCount: departures_count,
      newHiresCount: new_hires_count,
      dataCompletenessScore: data_completeness.score
    },
    summaryCard: {
      totalEmployeeCount: total_employee_count,
      activeEmployeeCount: active_employee_count,
      departuresCount: departures_count,
      newHiresCount: new_hires_count,
      dataCompletenessScore: data_completeness.score
    },
    headcountDistribution: headcount_distribution,
    headcountDistributionItems: headcount_distribution_items,
    departmentDistribution: department_distribution,
    employmentTypeDistribution: employment_type_distribution,
    employmentTypeDistributionItems: employment_type_distribution_items,
    newHiresCount: new_hires_count,
    departuresCount: departures_count,
    newHireExamples: new_hire_examples,
    departureExamples: departure_examples,
    dataCompleteness: data_completeness,
    narrativeSummary: {
      activeEmployeeCount: active_employee_count,
      terminatedEmployeeCount: terminated_employee_count,
      newHiresCount: new_hires_count,
      departuresCount: departures_count,
      topDepartment: department_distribution[0] ?? null,
      topEmploymentType: employment_type_distribution_items[0] ?? null,
      dataCompletenessScore: data_completeness.score
    }
  });
}

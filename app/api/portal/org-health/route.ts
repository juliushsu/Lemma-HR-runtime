import { compute_org_health, ensure_portal_access, load_monthly_attendance_health, load_people_base, ok } from "../_lib";

export async function GET(request: Request) {
  const schema_version = "portal.org_health.v1";
  const access = await ensure_portal_access(request);
  if (access.denied || !access.ctx || !access.scope) return access.denied;

  const loaded = await load_people_base(access.ctx, access.scope);
  if (loaded.error) return loaded.error;

  const health = compute_org_health(loaded.employees, loaded.departments, loaded.positions);
  const monthly_attendance_health = await load_monthly_attendance_health(access.ctx, access.scope);
  const department_stats = health.department_stats ?? [];
  const manager_ratio = Number(health.manager_ratio ?? 0);
  const org_structure_summary = health.org_structure_summary ?? {
    employee_count: 0,
    manager_count: 0,
    staff_count: 0,
    root_count: 0,
    orphan_count: 0
  };
  const active_department_count = department_stats.filter((d) => d.active !== false).length;
  const inactive_department_count = Math.max(department_stats.length - active_department_count, 0);
  const department_with_manager_count = department_stats.filter((d) => Number(d.manager_count ?? 0) > 0).length;
  const department_without_manager = department_stats
    .filter((d) => Number(d.manager_count ?? 0) === 0)
    .map((d) => ({
      department_id: d.department_id ?? null,
      department_name: d.department_name ?? "Unknown Department",
      member_count: Number(d.member_count ?? 0)
    }));
  const manager_coverage_ratio = department_stats.length === 0
    ? 0
    : Number((department_with_manager_count / department_stats.length).toFixed(4));
  const governance_settings_summary = {
    total_department_count: department_stats.length,
    active_department_count,
    inactive_department_count,
    department_with_manager_count,
    department_without_manager_count: Math.max(department_stats.length - department_with_manager_count, 0),
    manager_ratio,
    manager_coverage_ratio
  };
  const manager_coverage_summary = {
    department_with_manager_count,
    department_without_manager_count: department_without_manager.length,
    department_without_manager,
    manager_coverage_ratio
  };
  const attendance_health_summary = {
    month_key: monthly_attendance_health.month_key,
    attendance_rate: monthly_attendance_health.attendance_rate,
    total_logs: monthly_attendance_health.total_logs,
    healthy_target: 0.9,
    is_healthy: Number(monthly_attendance_health.attendance_rate ?? 0) >= 0.9
  };
  const jurisdiction = {
    country: null as string | null,
    legal_system: null as string | null,
    locale: null as string | null,
    timezone: null as string | null
  };

  return ok(schema_version, {
    org_id: access.scope.org_id,
    company_id: access.scope.company_id,
    department_stats,
    manager_ratio,
    org_structure_summary,
    governance_settings_summary,
    manager_coverage_summary,
    monthly_attendance_health,
    jurisdiction,
    attendance_health_summary,
    narrative_summary: {
      manager_ratio,
      manager_coverage_ratio,
      department_without_manager_count: department_without_manager.length,
      attendance_rate: monthly_attendance_health.attendance_rate,
      org_root_count: Number(org_structure_summary.root_count ?? 0),
      org_orphan_count: Number(org_structure_summary.orphan_count ?? 0)
    },
    page_sections: {
      org_structure_summary,
      governance_settings_summary,
      manager_coverage_summary,
      monthly_attendance_health,
      jurisdiction
    },
    // camelCase aliases for frontend adapters that normalize DTO keys on the client side.
    departmentStats: department_stats,
    managerRatio: manager_ratio,
    orgStructureSummary: org_structure_summary,
    governanceSettingsSummary: governance_settings_summary,
    managerCoverageSummary: manager_coverage_summary,
    monthlyAttendanceHealth: monthly_attendance_health,
    jurisdictionInfo: jurisdiction,
    attendanceHealthSummary: attendance_health_summary,
    narrativeSummary: {
      managerRatio: manager_ratio,
      managerCoverageRatio: manager_coverage_ratio,
      departmentWithoutManagerCount: department_without_manager.length,
      attendanceRate: monthly_attendance_health.attendance_rate,
      orgRootCount: Number(org_structure_summary.root_count ?? 0),
      orgOrphanCount: Number(org_structure_summary.orphan_count ?? 0)
    },
    pageSections: {
      orgStructureSummary: org_structure_summary,
      governanceSettingsSummary: governance_settings_summary,
      managerCoverageSummary: manager_coverage_summary,
      monthlyAttendanceHealth: monthly_attendance_health,
      jurisdiction
    }
  });
}

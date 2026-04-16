export type AttendanceBoundaryRow = {
  branch_id: string | null;
  checkin_radius_m: number | null;
  is_attendance_enabled: boolean | null;
};

export function resolve_attendance_boundary(params: {
  boundaries: AttendanceBoundaryRow[] | null | undefined;
  resolved_branch_id: string | null;
  location_is_attendance_enabled?: boolean | null;
  company_is_attendance_enabled?: boolean | null;
}) {
  const boundary_rows = (params.boundaries ?? []) as AttendanceBoundaryRow[];
  const company_default = boundary_rows.find((row) => !row.branch_id) ?? null;
  const branch_override = params.resolved_branch_id
    ? boundary_rows.find((row) => row.branch_id === params.resolved_branch_id) ?? null
    : null;

  const checkin_radius_m = branch_override?.checkin_radius_m ?? company_default?.checkin_radius_m ?? null;
  const location_enabled =
    branch_override?.is_attendance_enabled ??
    params.location_is_attendance_enabled ??
    company_default?.is_attendance_enabled ??
    true;
  const company_enabled = params.company_is_attendance_enabled ?? true;
  const is_attendance_enabled = Boolean(company_enabled && location_enabled);
  const resolved_from = branch_override ? "branch_override" : company_default ? "company_default" : "none";

  return {
    company_default,
    branch_override,
    checkin_radius_m,
    location_enabled,
    company_enabled,
    is_attendance_enabled,
    resolved_from
  };
}

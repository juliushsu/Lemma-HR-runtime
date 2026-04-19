# HR Employee Detail Null Policy v1

Status: formal UI render rule

Purpose:

- define how employee detail UI must render `null`, missing, and system-default states
- prevent frontend from treating every empty field as the same kind of problem
- make data gaps visually distinguishable from valid empty states and system-derived defaults

Scope:

- employee detail read/view mode
- employee detail edit/view fallback display
- section-level empty state behavior for grouped fields such as emergency contact

This document defines render behavior only.
It does not define write logic, validation logic, or API behavior.

## 1. Null Classification Model

Every employee detail field must be interpreted as one of the following:

### Class A: `null` is allowed

Meaning:

- `null` is a valid business state
- absence of value does not imply bad seed or broken data pipeline

UI rule:

- display `—`
- do not show warning badge
- do not show info badge unless another separate rule requires it

Typical examples:

- `manager_employee_id` for top-level/root employee
- `manager_name` for top-level/root employee
- `termination_date` for active employee
- optional secondary personal fields when product intentionally allows them to be empty

### Class B: should have seed / likely data gap

Meaning:

- field is expected to exist for pilot-quality employee master data
- missing value is treated as data incompleteness
- root cause is usually seed, onboarding data population, or upstream data pipeline

UI rule:

- display `尚未設定`
- show `warning badge`
- treat as data completeness issue, not just a neutral empty value

Typical examples:

- `full_name_local`
- `full_name_latin`
- `gender`
- `nationality_code`
- `birth_date`
- `work_email`
- `mobile_phone`
- `emergency_contact_name`
- `emergency_contact_phone`
- `hire_date`
- `department_id`
- `department_name`
- `position_id`
- `position_title`

### Class C: system default / not explicitly set

Meaning:

- displayed value may be resolved from system default, tenant default, or inherited fallback behavior
- missing explicit user-level value is not necessarily a seed/data failure

UI rule:

- display `使用系統預設`
- show `info badge`
- avoid warning styling because the system still has a valid fallback interpretation

Typical examples:

- `preferred_locale` when not explicitly set but runtime can fall back to org/company default
- `timezone` when not explicitly set but runtime can fall back to system or tenant default

## 2. Field-Level Render Matrix

| Field | Class | UI display when missing / null | Notes |
| --- | --- | --- | --- |
| `full_name_local` | B | `尚未設定` + warning badge | pilot data should normally provide localized full name |
| `full_name_latin` | B | `尚未設定` + warning badge | pilot data should normally provide latin full name |
| `gender` | B | `尚未設定` + warning badge | treat as missing master data |
| `nationality_code` | B | `尚未設定` + warning badge | if code missing, localized label is also missing |
| `birth_date` | B | `尚未設定` + warning badge | treat as missing master data |
| `work_email` | B | `尚未設定` + warning badge | employee binding and HR flows usually depend on this |
| `mobile_phone` | B | `尚未設定` + warning badge | pilot employee profile should normally include this |
| `emergency_contact_name` | B | `尚未設定` + warning badge | section-level rule also applies |
| `emergency_contact_phone` | B | `尚未設定` + warning badge | section-level rule also applies |
| `preferred_locale` | C | `使用系統預設` + info badge | use warning only if product later requires explicit user override |
| `timezone` | C | `使用系統預設` + info badge | same rule as locale |
| `employment_type` | B | `尚未設定` + warning badge | should exist for HR pilot master data |
| `employment_status` | B | `尚未設定` + warning badge | should exist for HR pilot master data |
| `hire_date` | B | `尚未設定` + warning badge | should exist for HR pilot master data |
| `department_id` | B | `尚未設定` + warning badge | reference is expected for most employee detail records |
| `department_name` | B | `尚未設定` + warning badge | treat as missing derived display because master reference is incomplete |
| `position_id` | B | `尚未設定` + warning badge | reference is expected for most employee detail records |
| `position_title` | B | `尚未設定` + warning badge | treat as missing derived display because master reference is incomplete |
| `manager_employee_id` | A | `—` | valid `null` for root employee |
| `manager_name` | A | `—` | valid `null` when there is no manager |

## 3. Badge Semantics

### Warning badge

Use warning badge only when the field is Class B.

Meaning:

- this field is expected to have data
- missing value suggests incomplete seed or incomplete master data population

The warning badge must not be used for:

- valid business nulls
- system-default fallback behavior

### Info badge

Use info badge only when the field is Class C.

Meaning:

- user-level value is not explicitly set
- runtime is using a valid fallback/default interpretation

The info badge must not imply broken data.

## 4. Section-Level Render Rules

### Emergency Contact section

Fields:

- `emergency_contact_name`
- `emergency_contact_phone`

Rules:

- if both fields are missing:
  - section summary displays `尚未設定`
  - section header or summary area shows one warning badge
  - do not duplicate multiple warning badges just because two subfields are empty
- if only one field is missing:
  - missing field shows `尚未設定` + warning badge
  - populated field renders normally
- if both fields are present:
  - render normally
  - no warning badge

### Manager section

Fields:

- `manager_employee_id`
- `manager_name`

Rules:

- if employee is a root/top-level employee and manager fields are null:
  - display `—`
  - no warning badge
- do not treat root-manager null as data incompleteness

### Locale / Timezone section

Fields:

- `preferred_locale`
- `timezone`

Rules:

- if field is missing and system default applies:
  - display `使用系統預設`
  - show info badge
- if product later removes default fallback and starts requiring explicit values:
  - reclassify from Class C to Class B in a future version of this spec

## 5. Render Rule Priority

When deciding what to show:

1. determine field class first
2. then apply field-level render rule
3. then apply section-level rule if the field belongs to a grouped section

Do not infer class from UI preference alone.

Class comes from data semantics, not from visual taste.

## 6. Non-Negotiable Rules

- UI must not collapse Class A, B, and C into one generic empty state
- UI must not display warning badge for valid business nulls
- UI must not display `—` for fields that are expected pilot data gaps
- UI must not treat system-default fallback as missing-data warning

## 7. Summary

Render behavior must follow this mapping:

- Class A -> `—`
- Class B -> `尚未設定` + warning badge
- Class C -> `使用系統預設` + info badge

This policy exists so employee detail UI can distinguish:

- valid empty state
- missing data state
- defaulted system state

#!/usr/bin/env bash
set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env: $name" >&2
    exit 1
  fi
}

require_env BASE_URL
require_env AUTH_TOKEN
require_env COOKIE_HEADER
require_env REQUEST_EMPLOYEE_ID
require_env LEAVE_TYPE
require_env START_AT
require_env END_AT

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

auth_headers=(
  -H "Authorization: Bearer ${AUTH_TOKEN}"
  -H "Cookie: ${COOKIE_HEADER}"
  -H "Content-Type: application/json"
)

create_payload="$(cat <<JSON
{
  "employee_id": "${REQUEST_EMPLOYEE_ID}",
  "leave_type": "${LEAVE_TYPE}",
  "start_at": "${START_AT}",
  "end_at": "${END_AT}",
  "reason": "${REASON:-controlled smoke}"
}
JSON
)"

echo "== Create leave request =="
curl -sS "${auth_headers[@]}" \
  -X POST \
  "${BASE_URL}/api/hr/leave-requests" \
  -d "$create_payload" > "$TMP_DIR/create.json"

jq '.' "$TMP_DIR/create.json"

REQUEST_ID="$(jq -r '.data.id // empty' "$TMP_DIR/create.json")"
if [[ -z "$REQUEST_ID" ]]; then
  echo "Create did not return data.id" >&2
  exit 1
fi

echo
echo "== Detail after create =="
curl -sS "${auth_headers[@]}" \
  "${BASE_URL}/api/hr/leave-requests/${REQUEST_ID}" > "$TMP_DIR/detail_after_create.json"
jq '.' "$TMP_DIR/detail_after_create.json"

STEP0_APPROVER="${STEP0_APPROVER_EMPLOYEE_ID:-$(jq -r '.data.approval_steps[0].approver_employee_id // empty' "$TMP_DIR/detail_after_create.json")}"
STEP1_APPROVER="${STEP1_APPROVER_EMPLOYEE_ID:-$(jq -r '.data.approval_steps[1].approver_employee_id // empty' "$TMP_DIR/detail_after_create.json")}"

if [[ -n "$STEP0_APPROVER" && "${RUN_APPROVE_STEP0:-true}" == "true" ]]; then
  echo
  echo "== Approve current step =="
  curl -sS "${auth_headers[@]}" \
    -X POST \
    "${BASE_URL}/api/hr/leave-requests/${REQUEST_ID}/approve" \
    -d "{\"approver_employee_id\":\"${STEP0_APPROVER}\",\"comment\":\"${APPROVE_COMMENT:-controlled smoke approve}\"}" \
    > "$TMP_DIR/approve.json"
  jq '.' "$TMP_DIR/approve.json"
fi

if [[ "${RUN_REJECT_CURRENT_STEP:-true}" == "true" ]]; then
  CURRENT_REJECT_APPROVER="${REJECT_APPROVER_EMPLOYEE_ID:-$STEP1_APPROVER}"
  if [[ -z "$CURRENT_REJECT_APPROVER" ]]; then
    CURRENT_REJECT_APPROVER="$STEP0_APPROVER"
  fi

  if [[ -n "$CURRENT_REJECT_APPROVER" ]]; then
    echo
    echo "== Reject current step =="
    curl -sS "${auth_headers[@]}" \
      -X POST \
      "${BASE_URL}/api/hr/leave-requests/${REQUEST_ID}/reject" \
      -d "{\"approver_employee_id\":\"${CURRENT_REJECT_APPROVER}\",\"comment\":\"${REJECT_COMMENT:-controlled smoke reject}\"}" \
      > "$TMP_DIR/reject.json"
    jq '.' "$TMP_DIR/reject.json"
  fi
fi

echo
echo "== Detail after mutations =="
curl -sS "${auth_headers[@]}" \
  "${BASE_URL}/api/hr/leave-requests/${REQUEST_ID}" > "$TMP_DIR/detail_after_mutation.json"
jq '.' "$TMP_DIR/detail_after_mutation.json"

echo
echo "== List summary =="
curl -sS "${auth_headers[@]}" \
  "${BASE_URL}/api/hr/leave-requests?employee_id=${REQUEST_EMPLOYEE_ID}" > "$TMP_DIR/list.json"
jq '.' "$TMP_DIR/list.json"

echo
echo "Controlled smoke completed for request: ${REQUEST_ID}"

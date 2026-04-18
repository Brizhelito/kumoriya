#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Force a user out of their current watch-party room through the Cloudflare worker.

Usage:
  scripts/force_party_leave.sh [user_uuid]

Environment:
  PARTY_REALTIME_BASE_URL   Worker base URL
                            Default: https://party.kumoriya.online
  PARTY_INTERNAL_TOKEN      Required bearer token for internal worker routes

Examples:
  scripts/force_party_leave.sh
  PARTY_INTERNAL_TOKEN=xxx scripts/force_party_leave.sh 8b9d7c8d-1234-4abc-9876-0123456789ab
  PARTY_REALTIME_BASE_URL=https://your-worker.example.workers.dev \
  PARTY_INTERNAL_TOKEN=xxx \
  scripts/force_party_leave.sh 8b9d7c8d-1234-4abc-9876-0123456789ab
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

USER_ID="${1:-}"
BASE_URL="${PARTY_REALTIME_BASE_URL:-https://party.kumoriya.online}"
TOKEN="${PARTY_INTERNAL_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  read -r -s -p "PARTY_INTERNAL_TOKEN: " TOKEN
  echo >&2
fi

if [[ -z "$TOKEN" ]]; then
  echo "error: empty PARTY_INTERNAL_TOKEN" >&2
  exit 1
fi

if [[ -z "$USER_ID" ]]; then
  read -r -p "User UUID: " USER_ID
fi

if [[ -z "$USER_ID" ]]; then
  echo "error: empty user UUID" >&2
  exit 1
fi

ENDPOINT="${BASE_URL%/}/internal/v1/users/${USER_ID}/force-leave"
RESPONSE_FILE="$(mktemp /tmp/party_force_leave.XXXXXX.json)"
trap 'rm -f "${RESPONSE_FILE}"' EXIT

echo "POST ${ENDPOINT}" >&2

HTTP_CODE="$(
  curl --silent --show-error \
    --output "${RESPONSE_FILE}" \
    --write-out '%{http_code}' \
    --request POST \
    --header "Authorization: Bearer ${TOKEN}" \
    --header 'Content-Type: application/json' \
    "${ENDPOINT}"
)"

echo "status=${HTTP_CODE}" >&2
cat "${RESPONSE_FILE}"
echo

if [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
  exit 1
fi

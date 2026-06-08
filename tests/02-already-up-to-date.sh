#!/usr/bin/env bash
# Test 2 — Already up to date
#
# Triggers the workflow when develop has nothing new for the store.
# Expects: main.yml runs cleanly, exits as no-op.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh
trap 'git checkout "${FROM_BRANCH}" 2>/dev/null || true' EXIT

echo ""
echo "Test 2 — No-op (develop has nothing new for the store)"
echo "───────────────────────────────────────────────────────"

git checkout "${FROM_BRANCH}"

info "Triggering workflow with no new changes (workflow_dispatch)"

# Record current latest run before triggering
PREV_RUN_ID=$(/opt/homebrew/bin/gh run list \
  --repo "${REPO}" --workflow main.yml --branch "${FROM_BRANCH}" \
  --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")

/opt/homebrew/bin/gh workflow run main.yml --repo "${REPO}" --ref "${FROM_BRANCH}"

# Poll until a new run appears
local_attempts=0
RUN_ID=""
while [[ ${local_attempts} -lt 20 ]]; do
  sleep 3
  RUN_ID=$(/opt/homebrew/bin/gh run list \
    --repo "${REPO}" --workflow main.yml --branch "${FROM_BRANCH}" \
    --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
  if [[ -n "${RUN_ID}" && "${RUN_ID}" != "${PREV_RUN_ID}" ]]; then
    break
  fi
  local_attempts=$((local_attempts + 1))
done

if [[ -z "${RUN_ID}" || "${RUN_ID}" == "${PREV_RUN_ID}" ]]; then
  echo -e "\033[0;31m  ✖ FAIL\033[0m  No new Actions run appeared after workflow_dispatch"
  exit 1
fi

info "Watching Actions run ${RUN_ID} — https://github.com/${REPO}/actions/runs/${RUN_ID}"
/opt/homebrew/bin/gh run watch "${RUN_ID}" --repo "${REPO}" --exit-status
RUN_CONCLUSION=$(/opt/homebrew/bin/gh run view "${RUN_ID}" \
  --repo "${REPO}" --json conclusion --jq '.conclusion')

echo ""
assert_workflow_succeeded
echo ""
echo "Test 2 passed."

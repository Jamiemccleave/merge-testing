#!/usr/bin/env bash
# Test 2 — Already up to date
#
# Triggers the workflow when develop has nothing new for the store.
# Expects: main.yml runs cleanly, exits as no-op.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh

echo ""
echo "Test 2 — No-op (develop has nothing new for the store)"
echo "───────────────────────────────────────────────────────"

git checkout "${FROM_BRANCH}"

info "Triggering workflow with no new changes (workflow_dispatch)"
/opt/homebrew/bin/gh workflow run main.yml --repo "${REPO}" --ref "${FROM_BRANCH}"

sleep 6
RUN_ID=$(/opt/homebrew/bin/gh run list \
  --repo "${REPO}" --workflow main.yml --branch "${FROM_BRANCH}" \
  --limit 1 --json databaseId --jq '.[0].databaseId')

info "Watching Actions run ${RUN_ID} — https://github.com/${REPO}/actions/runs/${RUN_ID}"
/opt/homebrew/bin/gh run watch "${RUN_ID}" --repo "${REPO}" --exit-status
RUN_CONCLUSION=$(/opt/homebrew/bin/gh run view "${RUN_ID}" \
  --repo "${REPO}" --json conclusion --jq '.conclusion')

echo ""
assert_workflow_succeeded
echo ""
echo "Test 2 passed."

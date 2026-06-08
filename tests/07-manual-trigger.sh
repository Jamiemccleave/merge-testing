#!/usr/bin/env bash
# Test 7 — Manual workflow_dispatch trigger
#
# Simulates: an operator manually re-runs the deploy from the Actions tab
# (workflow_dispatch). No push to develop — the trigger is manual.
#
# This covers the production scenario where a store deploy needs to be
# re-triggered after a failed run or when setting up a new region.
#
# Pass: workflow exits 0. The store branch is in sync with develop.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh

echo ""
echo "Test 7 — Manual workflow_dispatch trigger (operator-initiated deploy)"
echo "──────────────────────────────────────────────────────────────────────"

# ── Trigger the workflow manually (no push, no new commits) ──────────────────
info "Triggering main.yml via workflow_dispatch (no push to develop)"
/opt/homebrew/bin/gh workflow run main.yml --repo "${REPO}" --ref "${FROM_BRANCH}"

sleep 8

RUN_ID=$(/opt/homebrew/bin/gh run list \
  --repo "${REPO}" \
  --workflow main.yml \
  --branch "${FROM_BRANCH}" \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')

info "Watching Actions run ${RUN_ID} — https://github.com/${REPO}/actions/runs/${RUN_ID}"
/opt/homebrew/bin/gh run watch "${RUN_ID}" --repo "${REPO}" --exit-status
RUN_CONCLUSION=$(/opt/homebrew/bin/gh run view "${RUN_ID}" \
  --repo "${REPO}" --json conclusion --jq '.conclusion')
info "Run finished: ${RUN_CONCLUSION}"

# ── Assert ────────────────────────────────────────────────────────────────────
echo ""
assert_workflow_succeeded

echo ""
echo "Test 7 passed."

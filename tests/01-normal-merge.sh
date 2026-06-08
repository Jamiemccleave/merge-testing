#!/usr/bin/env bash
# Test 1 — Normal merge
#
# Simulates a developer pushing a new CSS component to develop.
# Expects: main.yml runs, change lands on devstores/storeone.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh

echo ""
echo "Test 1 — Normal merge (developer pushes new component to develop)"
echo "──────────────────────────────────────────────────────────────────"

git checkout "${FROM_BRANCH}"

info "Adding new CSS component to develop"
make_test_commit \
  "feat: test sale badge styles" \
  "assets/test-sale-badge.css" \
  ".test-sale-badge { background: red; color: white; }"

trigger_and_wait

echo ""
assert_workflow_succeeded
assert_store_contains "assets/test-sale-badge.css" "test-sale-badge"

revert_commits 1
echo ""
echo "Test 1 passed."

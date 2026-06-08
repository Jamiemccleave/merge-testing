#!/usr/bin/env bash
# Test 6 — Brand new store branch
#
# Simulates: a new store is being set up for the first time.
# The to_branch does not exist on the remote yet.
# The deployer should create it and push successfully.
#
# Pass: action exits 0 AND the new branch exists on remote with source content.

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

echo ""
echo "Test 6 — Brand new store branch (first-ever deploy to a new store)"
echo "────────────────────────────────────────────────────────────────────"

make_branches "new-src" "new-store"
setup_clone
fetch_deployer

# ── Source: develop with some theme code ─────────────────
info "Creating source branch (develop — existing theme)"
git -C "${WORK_DIR}" checkout -b "${TEST_SRC}" "origin/develop"
echo ".new-store-badge { display: block; }" > "${WORK_DIR}/assets/new-store.css"
git -C "${WORK_DIR}" add assets/new-store.css
git -C "${WORK_DIR}" commit -m "feat: new store launch styles"
git -C "${WORK_DIR}" push origin "${TEST_SRC}"

# ── Target: does NOT exist yet ────────────────────────────
info "Target branch '${TEST_TGT}' intentionally not created — simulates new store"

# ── Run deployer ──────────────────────────────────────────
# The deployer's `git checkout -b` path handles branch creation
run_deployer "${TEST_SRC}" "${TEST_TGT}"

# ── Assert ────────────────────────────────────────────────
echo ""

# Branch should now exist on remote
git -C "${WORK_DIR}" fetch --quiet origin 2>/dev/null || true
if git -C "${WORK_DIR}" ls-remote --exit-code origin "${TEST_TGT}" > /dev/null 2>&1; then
  pass "New store branch '${TEST_TGT}' was created on remote"
else
  fail "Branch '${TEST_TGT}' was not pushed to remote"
fi

# Source content should be on the new branch
assert_file_contains "${TEST_TGT}" "assets/new-store.css" "new-store-badge"

cleanup "${TEST_SRC}" "${TEST_TGT}"
echo ""
echo "Test 6 passed."

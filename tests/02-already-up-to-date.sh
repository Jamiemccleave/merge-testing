#!/usr/bin/env bash
# Test 2 — Already up to date
#
# Simulates: the deployer is triggered twice in a row with no new commits in between.
# The second run should detect nothing to merge and exit cleanly without pushing.
#
# Pass: action exits 0 AND the store branch SHA is unchanged after the second run.

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

echo ""
echo "Test 2 — Already up to date (deployer triggered with no new changes)"
echo "──────────────────────────────────────────────────────────────────────"

make_branches "noop-src" "noop-tgt"
setup_clone
fetch_deployer

# ── Both branches start at the same commit ────────────────
info "Creating source and target at identical commit (nothing to merge)"
git -C "${WORK_DIR}" checkout -b "${TEST_SRC}" "origin/develop"
git -C "${WORK_DIR}" push origin "${TEST_SRC}"

git -C "${WORK_DIR}" checkout -b "${TEST_TGT}" "origin/develop"
git -C "${WORK_DIR}" push origin "${TEST_TGT}"

# Capture target SHA before run
TGT_SHA_BEFORE=$(git -C "${WORK_DIR}" rev-parse "origin/${TEST_TGT}")
info "Target SHA before run: ${TGT_SHA_BEFORE}"

# ── Run deployer ──────────────────────────────────────────
run_deployer "${TEST_SRC}" "${TEST_TGT}"

# ── Assert ────────────────────────────────────────────────
echo ""
assert_sha_unchanged "${TEST_TGT}" "${TGT_SHA_BEFORE}"

cleanup "${TEST_SRC}" "${TEST_TGT}"
echo ""
echo "Test 2 passed."

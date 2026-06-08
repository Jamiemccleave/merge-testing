#!/usr/bin/env bash
# Test 4 — Hotfix on store branch
#
# Simulates: developer pushes a hotfix commit directly to the store branch
# (bypassing develop) to fix something urgently. Then the deployer runs.
#
# The deployer does `git pull` before merging so it picks up the hotfix.
# The merge commit sits on top of it — plain push should be fast-forward.
#
# Pass: action exits 0 AND both the hotfix AND the develop change are in
#       the target branch history after the run.

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

echo ""
echo "Test 4 — Hotfix on store branch (deployer runs after direct commit to store)"
echo "─────────────────────────────────────────────────────────────────────────────"

make_branches "hotfix-src" "hotfix-tgt"
setup_clone
fetch_deployer

# ── Source branch: new theme code ────────────────────────
info "Creating source branch (new theme feature on develop)"
git -C "${WORK_DIR}" checkout -b "${TEST_SRC}" "origin/develop"
echo ".sale-badge { background: red; }" > "${WORK_DIR}/assets/sale-badge.css"
git -C "${WORK_DIR}" add assets/sale-badge.css
git -C "${WORK_DIR}" commit -m "feat: sale badge styles"
git -C "${WORK_DIR}" push origin "${TEST_SRC}"

# ── Target branch: store branch with a direct hotfix ─────
info "Creating target branch then adding a direct hotfix commit"
git -C "${WORK_DIR}" checkout -b "${TEST_TGT}" "origin/devstores/storeone"
git -C "${WORK_DIR}" push origin "${TEST_TGT}"

# Simulate a developer pushing a hotfix directly to the store branch
echo "/* emergency price fix */" >> "${WORK_DIR}/assets/base.css"
git -C "${WORK_DIR}" add assets/base.css
git -C "${WORK_DIR}" commit -m "hotfix: emergency price display fix"
git -C "${WORK_DIR}" push origin "${TEST_TGT}"

HOTFIX_SHA=$(git -C "${WORK_DIR}" rev-parse HEAD)
info "Hotfix commit on store branch: ${HOTFIX_SHA}"

# ── Run deployer ──────────────────────────────────────────
run_deployer "${TEST_SRC}" "${TEST_TGT}"

# ── Assert ────────────────────────────────────────────────
echo ""

# Hotfix must still be in store branch history (not overwritten)
git -C "${WORK_DIR}" fetch --quiet origin "${TEST_TGT}"
if git -C "${WORK_DIR}" merge-base --is-ancestor "${HOTFIX_SHA}" "origin/${TEST_TGT}"; then
  pass "Hotfix commit preserved in store branch history"
else
  fail "Hotfix commit was lost — force push would have clobbered it"
fi

# New theme code from source must also be present
assert_file_contains "${TEST_TGT}" "assets/sale-badge.css" "sale-badge"

cleanup "${TEST_SRC}" "${TEST_TGT}"
echo ""
echo "Test 4 passed."

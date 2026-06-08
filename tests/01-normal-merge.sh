#!/usr/bin/env bash
# Test 1 — Normal merge
#
# Simulates: a developer ships a new header component to develop.
# The deployer should merge it into the store branch using a plain push (no force).
#
# Pass: action exits 0 AND the new commit appears in the store branch history.

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

echo ""
echo "Test 1 — Normal merge (developer ships code to develop)"
echo "────────────────────────────────────────────────────────"

make_branches "src" "tgt"
setup_clone
fetch_deployer

# ── Simulate human change on develop ─────────────────────
info "Creating source branch (developer pushed a new component)"
git -C "${WORK_DIR}" checkout -b "${TEST_SRC}" "origin/develop"
mkdir -p "${WORK_DIR}/assets"
cat > "${WORK_DIR}/assets/header-update.css" <<'CSS'
/* Header redesign — sprint 42 */
.site-header { background: #1a1a2e; }
CSS
git -C "${WORK_DIR}" add assets/header-update.css
git -C "${WORK_DIR}" commit -m "feat: new header styles (sprint 42)"
git -C "${WORK_DIR}" push origin "${TEST_SRC}"

# ── Target branch starts behind ───────────────────────────
info "Creating target branch (store branch — behind develop)"
git -C "${WORK_DIR}" checkout -b "${TEST_TGT}" "origin/devstores/storeone"
git -C "${WORK_DIR}" push origin "${TEST_TGT}"

# ── Run deployer ──────────────────────────────────────────
run_deployer "${TEST_SRC}" "${TEST_TGT}"

# ── Assert ────────────────────────────────────────────────
echo ""
assert_ancestor "${TEST_SRC}" "${TEST_TGT}"

# Confirm the CSS file made it across
assert_file_contains "${TEST_TGT}" "assets/header-update.css" "sprint 42"

cleanup "${TEST_SRC}" "${TEST_TGT}"
echo ""
echo "Test 1 passed."

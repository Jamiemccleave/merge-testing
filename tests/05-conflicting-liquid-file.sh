#!/usr/bin/env bash
# Test 5 — Conflicting liquid file
#
# Simulates: both develop and the store branch have edited the same
# sections/header.liquid file. The deployer uses --strategy-option theirs
# so develop's version wins the conflict. Plain push should still work.
#
# Pass: action exits 0 AND the header.liquid on the store branch contains
#       the develop version (theirs strategy applied correctly).

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

echo ""
echo "Test 5 — Conflicting liquid file (same file edited on both branches)"
echo "──────────────────────────────────────────────────────────────────────"

make_branches "conflict-src" "conflict-tgt"
setup_clone
fetch_deployer

# ── Source: develop edits header.liquid ──────────────────
info "Creating source branch (develop version of header.liquid)"
git -C "${WORK_DIR}" checkout -b "${TEST_SRC}" "origin/develop"
mkdir -p "${WORK_DIR}/sections"
cat > "${WORK_DIR}/sections/header.liquid" <<'LIQUID'
<header class="site-header site-header--develop">
  <a href="/" class="site-header__logo">{{ shop.name }}</a>
</header>
LIQUID
git -C "${WORK_DIR}" add sections/header.liquid
git -C "${WORK_DIR}" commit -m "feat: updated header layout from develop"
git -C "${WORK_DIR}" push origin "${TEST_SRC}"

# ── Target: store branch has its own version of header.liquid ────
info "Creating target branch (store version of header.liquid — will be overwritten by theirs)"
git -C "${WORK_DIR}" checkout -b "${TEST_TGT}" "origin/devstores/storeone"
mkdir -p "${WORK_DIR}/sections"
cat > "${WORK_DIR}/sections/header.liquid" <<'LIQUID'
<header class="site-header site-header--storeone">
  <a href="/" class="site-header__logo">{{ shop.name }} Store One</a>
</header>
LIQUID
git -C "${WORK_DIR}" add sections/header.liquid
git -C "${WORK_DIR}" commit -m "customisation: store one header branding"
git -C "${WORK_DIR}" push origin "${TEST_TGT}"

# ── Run deployer ──────────────────────────────────────────
run_deployer "${TEST_SRC}" "${TEST_TGT}"

# ── Assert ────────────────────────────────────────────────
echo ""

# develop's version should win (--strategy-option theirs = from_branch wins)
assert_file_contains "${TEST_TGT}" "sections/header.liquid" "site-header--develop"

# plain push succeeded — source is in target history
assert_ancestor "${TEST_SRC}" "${TEST_TGT}"

cleanup "${TEST_SRC}" "${TEST_TGT}"
echo ""
echo "Test 5 passed."

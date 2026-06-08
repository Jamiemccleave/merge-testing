#!/usr/bin/env bash
# Test 3 — Store config preserved
#
# Simulates: developer ships updated theme code that includes a different
# settings_data.json. The store has its own live merchant settings.
# The deployer must take the theme code but keep the store's config intact.
#
# Pass: after merge, target branch retains ITS OWN settings_data.json,
#       NOT the version from the source branch.

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

echo ""
echo "Test 3 — Store config preserved (merchant settings survive theme merge)"
echo "────────────────────────────────────────────────────────────────────────"

make_branches "cfg-src" "cfg-tgt"
setup_clone
fetch_deployer

# ── Source: new theme code with develop's config ──────────
info "Creating source branch (develop — has theme changes + develop settings)"
git -C "${WORK_DIR}" checkout -b "${TEST_SRC}" "origin/develop"

# New theme component (should land on store branch)
mkdir -p "${WORK_DIR}/assets"
echo ".promo-banner { display: block; }" > "${WORK_DIR}/assets/promo-banner.css"

# Develop has its own settings_data — this must NOT overwrite the store's
mkdir -p "${WORK_DIR}/config"
printf '{"current":"develop-default-theme","version":"dev"}' \
  > "${WORK_DIR}/config/settings_data.json"

git -C "${WORK_DIR}" add assets/promo-banner.css config/settings_data.json
git -C "${WORK_DIR}" commit -m "feat: promo banner + dev config"
git -C "${WORK_DIR}" push origin "${TEST_SRC}"

# ── Target: store branch with live merchant settings ──────
info "Creating target branch (store — has live merchant settings)"
git -C "${WORK_DIR}" checkout -b "${TEST_TGT}" "origin/devstores/storeone"

mkdir -p "${WORK_DIR}/config"
printf '{"current":"jamie-test-dev-live","version":"store"}' \
  > "${WORK_DIR}/config/settings_data.json"

git -C "${WORK_DIR}" add config/settings_data.json
git -C "${WORK_DIR}" commit -m "chore: live store merchant settings"
git -C "${WORK_DIR}" push origin "${TEST_TGT}"

# ── Run deployer ──────────────────────────────────────────
run_deployer "${TEST_SRC}" "${TEST_TGT}"

# ── Assert ────────────────────────────────────────────────
echo ""

# Store config must survive
assert_file_contains "${TEST_TGT}" "config/settings_data.json" "jamie-test-dev-live"

# Theme code from source must have landed
assert_file_contains "${TEST_TGT}" "assets/promo-banner.css" "promo-banner"

cleanup "${TEST_SRC}" "${TEST_TGT}"
echo ""
echo "Test 3 passed."

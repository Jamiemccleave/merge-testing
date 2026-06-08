#!/usr/bin/env bash
# Test 3 — Store config preserved
#
# Simulates: a developer pushes theme code to develop that includes changes to
# config/settings_data.json and templates/index.json. The store branch has its
# own live merchant versions of those files. After deploy, the store's JSON
# files must survive unchanged.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh
trap 'git checkout "${FROM_BRANCH}" 2>/dev/null || true' EXIT

TS=$(date +%s)

echo ""
echo "Test 3 — Store config preserved (merchant JSON survives theme deploy)"
echo "──────────────────────────────────────────────────────────────────────"

# ── Step 1: Set distinct config values on the store branch ───────────────────
info "Writing store-specific config to ${TO_BRANCH}"
git fetch --quiet origin "${TO_BRANCH}"
git checkout "${TO_BRANCH}" 2>/dev/null || git checkout -b "${TO_BRANCH}" "origin/${TO_BRANCH}"
git pull --quiet origin "${TO_BRANCH}"
mkdir -p config templates
printf '{"current":"jamie-test-dev-live","store":"storeone","ts":"%s"}' "${TS}" > config/settings_data.json
printf '{"sections":{"main":{"type":"featured-collection","settings":{"store":"storeone","ts":"%s"}}}}' "${TS}" > templates/index.json
git add config/settings_data.json templates/index.json
git commit -m "test: set storeone merchant config (${TS})"
git push origin "${TO_BRANCH}"

# ── Step 2: Push a theme change to develop (triggers deploy) ─────────────────
git checkout "${FROM_BRANCH}"
git pull --quiet origin "${FROM_BRANCH}"
make_test_commit \
  "feat: test promo banner component (${TS})" \
  "assets/test-promo-banner.css" \
  ".test-promo-banner { display: block; background: #ff6b00; /* ts:${TS} */ }"

trigger_and_wait

# ── Step 3: Assert store config survived ─────────────────────────────────────
echo ""
assert_workflow_succeeded
assert_store_contains "config/settings_data.json" "storeone"
assert_store_not_contains "config/settings_data.json" "develop"
assert_store_contains "templates/index.json" "storeone"
assert_store_contains "assets/test-promo-banner.css" "promo-banner"

revert_commits 1
echo ""
echo "Test 3 passed."

#!/usr/bin/env bash
# Test 5 — Conflicting liquid file
#
# Simulates: both develop and devstores/storeone have edited the same liquid
# file (sections/header.liquid). The deployer uses --strategy-option theirs so
# develop's version always wins. The push should be plain fast-forward — no
# force needed.
#
# Pass: workflow exits 0 AND sections/header.liquid on the store branch shows
#       develop's class name (site-header--develop), not the store's override.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh

echo ""
echo "Test 5 — Conflicting liquid file (develop version wins, plain push succeeds)"
echo "─────────────────────────────────────────────────────────────────────────────"

# ── Step 1: Commit the store's version of header.liquid ──────────────────────
info "Writing store-specific header.liquid to ${TO_BRANCH}"
git fetch --quiet origin "${TO_BRANCH}"
git checkout "${TO_BRANCH}" 2>/dev/null || git checkout -b "${TO_BRANCH}" "origin/${TO_BRANCH}"
git pull --quiet origin "${TO_BRANCH}"
mkdir -p sections
printf '<header class="site-header--storeone">Store One</header>' > sections/header.liquid
git add sections/header.liquid
git commit -m "test: storeone custom header branding"
git push origin "${TO_BRANCH}"

# ── Step 2: Push develop's conflicting version (triggers main.yml) ────────────
git checkout "${FROM_BRANCH}"
git pull --quiet origin "${FROM_BRANCH}"
make_test_commit \
  "feat: global header update (test 5)" \
  "sections/header.liquid" \
  '<header class="site-header--develop">{{ shop.name }}</header>'

trigger_and_wait

# ── Step 3: Assert develop's version won the conflict ────────────────────────
echo ""
assert_workflow_succeeded
assert_store_contains "sections/header.liquid" "site-header--develop"
assert_store_not_contains "sections/header.liquid" "site-header--storeone"

revert_commits 1
echo ""
echo "Test 5 passed."

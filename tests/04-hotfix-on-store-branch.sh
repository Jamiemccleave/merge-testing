#!/usr/bin/env bash
# Test 4 — Hotfix on store branch
#
# Simulates: a developer pushes a hotfix commit directly to devstores/storeone
# (bypassing develop) to fix something urgently. Then a normal develop → deploy
# runs on top.
#
# The deployer does `git pull` before merging so it picks up the remote store
# HEAD (including the hotfix). The resulting merge commit is a fast-forward
# push — no force needed.
#
# Pass: workflow exits 0, hotfix file still exists on store, AND the develop
#       change also lands on the store branch.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh

echo ""
echo "Test 4 — Hotfix on store branch (direct commit preserved through deploy)"
echo "─────────────────────────────────────────────────────────────────────────"

# ── Step 1: Push a hotfix directly to devstores/storeone ─────────────────────
info "Committing hotfix directly to ${TO_BRANCH}"
git fetch --quiet origin "${TO_BRANCH}"
git checkout "${TO_BRANCH}" 2>/dev/null || git checkout -b "${TO_BRANCH}" "origin/${TO_BRANCH}"
git pull --quiet origin "${TO_BRANCH}"
printf '.cart-price-fix { font-size: 1rem; }' > assets/hotfix-cart-price.css
git add assets/hotfix-cart-price.css
git commit -m "hotfix: cart price display bug fix"
git push origin "${TO_BRANCH}"
info "Hotfix pushed to ${TO_BRANCH}"

# ── Step 2: Push new theme code to develop (triggers main.yml) ───────────────
git checkout "${FROM_BRANCH}"
git pull --quiet origin "${FROM_BRANCH}"
make_test_commit \
  "feat: test promo section component" \
  "sections/test-promo-04.liquid" \
  "<section class=\"promo\"><!-- test 4 promo section --></section>"

trigger_and_wait

# ── Step 3: Assert both the hotfix AND the develop change are on store ────────
echo ""
assert_workflow_succeeded
assert_store_contains "assets/hotfix-cart-price.css" "cart-price-fix"
assert_store_contains "sections/test-promo-04.liquid" "promo"

revert_commits 1
echo ""
echo "Test 4 passed."

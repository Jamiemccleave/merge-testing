#!/usr/bin/env bash
# Test 6 — Store branch with many accumulated patches
#
# Simulates: a store branch that has several direct hotfix/patch commits on it
# (the store has diverged from develop over time with merchant customisations).
# A standard develop → deploy must still fast-forward without needing --force.
#
# The deployer always does `git pull origin ${to_branch}` before merging, so
# the merge commit's parent is always the current remote HEAD — making the push
# a plain fast-forward regardless of how many commits are on the store branch.
#
# Pass: workflow exits 0 AND all patch files still exist on the store branch
#       AND the new develop feature also landed.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source tests/helpers.sh

echo ""
echo "Test 6 — Many patches on store branch (plain push stays fast-forward)"
echo "────────────────────────────────────────────────────────────────────────"

# ── Step 1: Push 3 merchant patches directly to devstores/storeone ───────────
info "Pushing 3 direct merchant patches to ${TO_BRANCH}"
git fetch --quiet origin "${TO_BRANCH}"
git checkout "${TO_BRANCH}" 2>/dev/null || git checkout -b "${TO_BRANCH}" "origin/${TO_BRANCH}"
git pull --quiet origin "${TO_BRANCH}"

for i in 1 2 3; do
  printf ".merchant-patch-%s { display: block; }" "${i}" > "assets/merchant-patch-${i}.css"
  git add "assets/merchant-patch-${i}.css"
  git commit -m "merchant patch: style update ${i}"
done
git push origin "${TO_BRANCH}"
info "3 patches pushed to ${TO_BRANCH}"

# ── Step 2: Push a new develop feature (triggers main.yml) ───────────────────
git checkout "${FROM_BRANCH}"
git pull --quiet origin "${FROM_BRANCH}"
make_test_commit \
  "feat: test collection layout (test 6)" \
  "sections/test-collection-06.liquid" \
  "<section class=\"collection\"><!-- test 6 collection layout --></section>"

trigger_and_wait

# ── Step 3: Assert all patches + develop feature present ─────────────────────
echo ""
assert_workflow_succeeded
assert_store_contains "assets/merchant-patch-1.css" "merchant-patch-1"
assert_store_contains "assets/merchant-patch-2.css" "merchant-patch-2"
assert_store_contains "assets/merchant-patch-3.css" "merchant-patch-3"
assert_store_contains "sections/test-collection-06.liquid" "collection"

revert_commits 1
echo ""
echo "Test 6 passed."

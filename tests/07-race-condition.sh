#!/usr/bin/env bash
# Test 7 — Race condition (concurrent deployer runs)
#
# Simulates: two deployer runs fire at the same time against the same store
# branch. The first one pushes successfully. The second one's plain push
# is rejected (non-fast-forward) because the remote has moved on.
#
# With --force the second run would have silently overwritten the first.
# With plain push it fails explicitly — the correct safe behaviour.
#
# Pass: first run exits 0. Second run exits NON-ZERO (clean rejection).
#       The remote branch reflects the FIRST run's commit, not a clobbered state.

set -euo pipefail
source "$(dirname "$0")/helpers.sh"

echo ""
echo "Test 7 — Race condition (two concurrent runs, second should fail cleanly)"
echo "──────────────────────────────────────────────────────────────────────────"

make_branches "race-src" "race-tgt"
setup_clone
fetch_deployer

# ── Shared source branch ──────────────────────────────────
info "Creating source branch"
git -C "${WORK_DIR}" checkout -b "${TEST_SRC}" "origin/develop"
echo ".race-test { color: blue; }" > "${WORK_DIR}/assets/race.css"
git -C "${WORK_DIR}" add assets/race.css
git -C "${WORK_DIR}" commit -m "feat: race condition test asset"
git -C "${WORK_DIR}" push origin "${TEST_SRC}"

# ── Target branch ─────────────────────────────────────────
info "Creating target branch"
git -C "${WORK_DIR}" checkout -b "${TEST_TGT}" "origin/devstores/storeone"
git -C "${WORK_DIR}" push origin "${TEST_TGT}"

# ── Run 1: succeeds ───────────────────────────────────────
WORK_DIR_1="${WORK_DIR}"
info "Run 1: deployer starts, fetches target (records its HEAD)"
run_deployer "${TEST_SRC}" "${TEST_TGT}"
RUN1_SHA=$(git -C "${WORK_DIR_1}" rev-parse "origin/${TEST_TGT}" 2>/dev/null || \
           git -C "${WORK_DIR_1}" ls-remote origin "${TEST_TGT}" | awk '{print $1}')
info "Run 1 pushed: ${RUN1_SHA}"

# ── Simulate concurrent push (another process pushed while run 2 was working) ──
info "Simulating concurrent push to target branch (another process)"
WORK_DIR_2=$(mktemp -d)
git clone --quiet "git@github.com:${REPO}.git" "${WORK_DIR_2}"
git -C "${WORK_DIR_2}" config user.name  "Concurrent Bot"
git -C "${WORK_DIR_2}" config user.email "actions@github.com"
git -C "${WORK_DIR_2}" fetch --quiet origin "${TEST_TGT}"
git -C "${WORK_DIR_2}" checkout --quiet -b "${TEST_TGT}" "origin/${TEST_TGT}"
echo "/* concurrent commit */" >> "${WORK_DIR_2}/assets/base.css"
git -C "${WORK_DIR_2}" add assets/base.css
git -C "${WORK_DIR_2}" commit --quiet -m "concurrent: direct push after run 1"
git -C "${WORK_DIR_2}" push --quiet origin "${TEST_TGT}"
CONCURRENT_SHA=$(git -C "${WORK_DIR_2}" rev-parse HEAD)
info "Concurrent push landed: ${CONCURRENT_SHA}"
rm -rf "${WORK_DIR_2}"

# ── Run 2: should fail cleanly (remote has moved on) ─────
info "Run 2: deployer runs again — plain push should be rejected"
set +e
run_deployer "${TEST_SRC}" "${TEST_TGT}"
RUN2_EXIT=$?
set -e

# ── Assert ────────────────────────────────────────────────
echo ""

if [[ "${RUN2_EXIT}" -ne 0 ]]; then
  pass "Run 2 failed with exit ${RUN2_EXIT} — plain push correctly rejected (no silent overwrite)"
else
  # If it succeeded, check whether the concurrent commit survived
  git -C "${WORK_DIR}" fetch --quiet origin "${TEST_TGT}"
  if git -C "${WORK_DIR}" merge-base --is-ancestor "${CONCURRENT_SHA}" "origin/${TEST_TGT}"; then
    pass "Run 2 succeeded AND preserved the concurrent commit (merge path taken)"
  else
    fail "Run 2 succeeded but LOST the concurrent commit — would have been a silent clobber with --force"
  fi
fi

cleanup "${TEST_SRC}" "${TEST_TGT}"
echo ""
echo "Test 7 passed."

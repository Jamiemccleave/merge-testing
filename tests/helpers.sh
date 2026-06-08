#!/usr/bin/env bash
# Shared helpers for deployer test scripts.
# Tests push to develop, trigger the real main.yml workflow, then assert results.
# Source this file — do not run it directly.

set -euo pipefail

REPO="Jamiemccleave/merge-testing"
FROM_BRANCH="develop"
TO_BRANCH="devstores/storeone"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'
pass()  { echo -e "${GREEN}  ✔ PASS${RESET}  $*"; }
fail()  { echo -e "${RED}  ✖ FAIL${RESET}  $*"; exit 1; }
info()  { echo -e "${YELLOW}  →${RESET} $*"; }

# ── Push to develop and wait for the workflow to finish ──────────────────────
# Sets global: RUN_ID, RUN_CONCLUSION
trigger_and_wait() {
  info "Pushing to ${FROM_BRANCH} — triggering main.yml"
  git push origin "${FROM_BRANCH}"

  sleep 6

  RUN_ID=$(/opt/homebrew/bin/gh run list \
    --repo "${REPO}" \
    --workflow main.yml \
    --branch "${FROM_BRANCH}" \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId')

  info "Watching Actions run ${RUN_ID} — https://github.com/${REPO}/actions/runs/${RUN_ID}"
  /opt/homebrew/bin/gh run watch "${RUN_ID}" --repo "${REPO}" --exit-status
  RUN_CONCLUSION=$(/opt/homebrew/bin/gh run view "${RUN_ID}" \
    --repo "${REPO}" --json conclusion --jq '.conclusion')
  info "Run finished: ${RUN_CONCLUSION}"
}

# ── Commit a file change on develop ──────────────────────────────────────────
make_test_commit() {
  local msg="$1" file="$2" content="$3"
  git pull --quiet origin "${FROM_BRANCH}" 2>/dev/null || true
  mkdir -p "$(dirname "${file}")"
  printf '%s' "${content}" > "${file}"
  git add "${file}"
  git commit -m "${msg}"
}

# ── Revert the last N commits and push (keeps develop clean after each test) ─
revert_commits() {
  local n="${1:-1}"
  info "Reverting last ${n} commit(s) to clean up develop"
  for _ in $(seq 1 "${n}"); do
    git revert --no-edit HEAD
  done
  git push origin "${FROM_BRANCH}"
  sleep 6
  REVERT_RUN=$(/opt/homebrew/bin/gh run list \
    --repo "${REPO}" --workflow main.yml --branch "${FROM_BRANCH}" \
    --limit 1 --json databaseId --jq '.[0].databaseId')
  /opt/homebrew/bin/gh run watch "${REVERT_RUN}" --repo "${REPO}" --exit-status 2>/dev/null || true
}

# ── Assertions against the store branch ──────────────────────────────────────
assert_store_contains() {
  local file="$1" expected="$2"
  git fetch --quiet origin "${TO_BRANCH}"
  local content
  content=$(git show "origin/${TO_BRANCH}:${file}" 2>/dev/null || echo "")
  if echo "${content}" | grep -qF "${expected}"; then
    pass "${file} contains expected value on ${TO_BRANCH}"
  else
    fail "${file} missing '${expected}' on ${TO_BRANCH} — got: ${content}"
  fi
}

assert_store_not_contains() {
  local file="$1" unexpected="$2"
  git fetch --quiet origin "${TO_BRANCH}"
  local content
  content=$(git show "origin/${TO_BRANCH}:${file}" 2>/dev/null || echo "")
  if echo "${content}" | grep -qF "${unexpected}"; then
    fail "${file} should NOT contain '${unexpected}' on ${TO_BRANCH}"
  else
    pass "${file} correctly does not contain '${unexpected}' on ${TO_BRANCH}"
  fi
}

assert_workflow_succeeded() {
  if [[ "${RUN_CONCLUSION}" == "success" ]]; then
    pass "Workflow run succeeded (${RUN_ID})"
  else
    fail "Workflow run ${RUN_ID} concluded: ${RUN_CONCLUSION}"
  fi
}

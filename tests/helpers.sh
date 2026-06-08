#!/usr/bin/env bash
# Shared helpers for deployer test scripts.
# Source this file — do not run it directly.

set -euo pipefail

REPO="Jamiemccleave/merge-testing"
DEPLOYER_SCRIPT="https://raw.githubusercontent.com/Jamiemccleave/shopify-multi-store-deployer/fix/remove-force-push/entrypoint.sh"

# ── Colour output ─────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'
pass()  { echo -e "${GREEN}  ✔ PASS${RESET}  $*"; }
fail()  { echo -e "${RED}  ✖ FAIL${RESET}  $*"; exit 1; }
info()  { echo -e "${YELLOW}  →${RESET} $*"; }

# ── Token ─────────────────────────────────────────────────
# Uses `gh auth token` so no hardcoded secrets.
get_token() {
  gh auth token 2>/dev/null || { echo "Run 'gh auth login' first."; exit 1; }
}

# ── Unique branch names per test run ─────────────────────
# Usage: make_branches src_prefix tgt_prefix
#   Sets globals: TEST_SRC  TEST_TGT
make_branches() {
  local ts
  ts=$(date +%s)
  TEST_SRC="test/${1}-${ts}"
  TEST_TGT="test/${2}-${ts}"
}

# ── Spin up a clean clone in a temp dir ──────────────────
# Sets global: WORK_DIR
setup_clone() {
  WORK_DIR=$(mktemp -d)
  info "Cloning ${REPO} → ${WORK_DIR}"
  git clone --quiet "git@github.com:${REPO}.git" "${WORK_DIR}"
  git -C "${WORK_DIR}" config user.name  "Test Bot"
  git -C "${WORK_DIR}" config user.email "actions@github.com"
  git -C "${WORK_DIR}" fetch --quiet origin
}

# ── Download deployer entrypoint into the clone ──────────
fetch_deployer() {
  info "Fetching deployer entrypoint (fix/remove-force-push)"
  curl -fsSL "${DEPLOYER_SCRIPT}" -o "${WORK_DIR}/_deployer.sh"
  chmod +x "${WORK_DIR}/_deployer.sh"
}

# ── Run the deployer against the clone ───────────────────
# Usage: run_deployer <from_branch> <to_branch>
run_deployer() {
  local from="$1" to="$2"
  local token
  token=$(get_token)

  info "Running deployer: ${from} → ${to}"
  (
    cd "${WORK_DIR}"
    export INPUT_FROM_BRANCH="${from}"
    export INPUT_TO_BRANCH="${to}"
    export INPUT_USER_NAME="Test Bot"
    export INPUT_USER_EMAIL="actions@github.com"
    export INPUT_PUSH_TOKEN="DEPLOY_TOKEN"
    export DEPLOY_TOKEN="${token}"
    export GITHUB_WORKSPACE="${WORK_DIR}"
    export GITHUB_REPOSITORY="${REPO}"
    export GITHUB_STEP_SUMMARY=/dev/null
    bash _deployer.sh
  )
}

# ── Assertions ────────────────────────────────────────────
assert_ancestor() {
  local ancestor="$1" descendant="$2"
  git -C "${WORK_DIR}" fetch --quiet origin "${ancestor}" "${descendant}" 2>/dev/null || true
  if git -C "${WORK_DIR}" merge-base --is-ancestor \
      "origin/${ancestor}" "origin/${descendant}"; then
    pass "${ancestor} is in history of ${descendant}"
  else
    fail "${ancestor} was NOT merged into ${descendant}"
  fi
}

assert_file_contains() {
  local branch="$1" file="$2" expected="$3"
  git -C "${WORK_DIR}" fetch --quiet origin "${branch}" 2>/dev/null || true
  local content
  content=$(git -C "${WORK_DIR}" show "origin/${branch}:${file}" 2>/dev/null || echo "")
  if echo "${content}" | grep -qF "${expected}"; then
    pass "${file} contains expected value on ${branch}"
  else
    fail "${file} missing '${expected}' on ${branch} — got: ${content}"
  fi
}

assert_sha_unchanged() {
  local branch="$1" original_sha="$2"
  git -C "${WORK_DIR}" fetch --quiet origin "${branch}" 2>/dev/null || true
  local current_sha
  current_sha=$(git -C "${WORK_DIR}" rev-parse "origin/${branch}")
  if [ "${current_sha}" = "${original_sha}" ]; then
    pass "${branch} was not modified (correct no-op)"
  else
    fail "${branch} was unexpectedly modified"
  fi
}

# ── Cleanup ───────────────────────────────────────────────
cleanup() {
  info "Cleaning up test branches"
  for branch in "$@"; do
    git -C "${WORK_DIR}" push origin --delete "${branch}" 2>/dev/null || true
  done
  rm -rf "${WORK_DIR}"
}

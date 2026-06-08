#!/usr/bin/env bash
# Run all deployer tests.
# Usage: ./tests/run.sh [test-number]
#   ./tests/run.sh        — run all tests
#   ./tests/run.sh 1      — run only test 1

set -euo pipefail
TESTS_DIR="$(dirname "$0")"

run_test() {
  local script="$1"
  echo ""
  echo "════════════════════════════════════════════════════════"
  bash "${script}"
  echo "════════════════════════════════════════════════════════"
}

if [[ "${1:-}" != "" ]]; then
  run_test "${TESTS_DIR}/0${1}-"*.sh
else
  run_test "${TESTS_DIR}/01-normal-merge.sh"
  run_test "${TESTS_DIR}/02-already-up-to-date.sh"
  run_test "${TESTS_DIR}/03-config-preserved.sh"
  run_test "${TESTS_DIR}/04-hotfix-on-store-branch.sh"
  run_test "${TESTS_DIR}/05-conflicting-liquid-file.sh"
  run_test "${TESTS_DIR}/06-brand-new-store-branch.sh"
  run_test "${TESTS_DIR}/07-race-condition.sh"
  echo ""
  echo "All tests passed."
fi

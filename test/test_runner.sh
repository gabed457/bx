#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0
SKIP=0
FAILURES=()

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-assertion}"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: ${msg}"$'\n'"  expected: '${expected}'"$'\n'"  actual:   '${actual}'")
  fi
}

assert_not_eq() {
  local unexpected="$1" actual="$2" msg="${3:-assertion}"
  if [[ "$unexpected" != "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: ${msg}"$'\n'"  expected not: '${unexpected}'"$'\n'"  actual:       '${actual}'")
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: ${msg}"$'\n'"  expected to contain: '${needle}'"$'\n'"  in: '${haystack}'")
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-assert_not_contains}"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: ${msg}"$'\n'"  expected NOT to contain: '${needle}'"$'\n'"  in: '${haystack}'")
  fi
}

assert_match() {
  local pattern="$1" actual="$2" msg="${3:-assert_match}"
  if echo "$actual" | grep -qE "$pattern"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: ${msg}"$'\n'"  expected to match: '${pattern}'"$'\n'"  in: '${actual}'")
  fi
}

# Run all test files
for test_file in "$SCRIPT_DIR"/test_*.sh; do
  [[ -f "$test_file" ]] || continue
  [[ "$(basename "$test_file")" == "test_runner.sh" ]] && continue

  echo "Running $(basename "$test_file")..."

  # Source the test file
  source "$test_file"

  # Execute all functions starting with "test_"
  for func in $(declare -F | awk '{print $3}' | grep '^test_'); do
    echo -n "  $func... "
    fail_before=$FAIL
    "$func" || true
    if [[ $FAIL -eq $fail_before ]]; then
      echo "ok"
    else
      echo "FAILED"
    fi
    unset -f "$func" 2>/dev/null || true
  done
done

# Report
echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  for f in "${FAILURES[@]}"; do
    echo ""
    echo "$f"
  done
fi

[[ $FAIL -eq 0 ]] || exit 1

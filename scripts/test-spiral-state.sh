#!/usr/bin/env bash
# Test suite for spiral-state.sh — Stage 5 (TDD Red Phase)
# Tests that `status` output includes escalation count.
#
# Target behavior: status summary line should include "| Escalations: N"
# Feature not yet implemented — all tests expected to FAIL (Red state).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPIRAL_STATE="${SCRIPT_DIR}/spiral-state.sh"
STATE_FILE=".swe/active/spiral-state.json"

PASS=0
FAIL=0

# ─── Test helpers ───

_pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

_fail() {
  echo "  FAIL: $1"
  echo "        $2"
  FAIL=$((FAIL + 1))
}

_assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    _pass "$label"
  else
    _fail "$label" "Expected to find: '$needle' in output: '$haystack'"
  fi
}

# ─── State file lifecycle ───
# spiral-state.sh hardcodes STATE_FILE to ".swe/active/spiral-state.json"
# relative to cwd. We back up any existing state file, run tests from the
# project root, and restore on exit.

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_FILE="${PROJECT_ROOT}/.swe/active/spiral-state.json.test-backup"

_setup() {
  cd "$PROJECT_ROOT"

  # Back up existing state file if present
  if [[ -f "$STATE_FILE" ]]; then
    cp "$STATE_FILE" "$BACKUP_FILE"
    rm "$STATE_FILE"
  fi
}

_teardown() {
  cd "$PROJECT_ROOT"

  # Remove test state file
  [[ -f "$STATE_FILE" ]] && rm "$STATE_FILE"

  # Restore original state file if it was backed up
  if [[ -f "$BACKUP_FILE" ]]; then
    mv "$BACKUP_FILE" "$STATE_FILE"
  fi
}

trap _teardown EXIT

# ─── Test cases ───

# test_status_contains_escalations_when_zero
# Arrange: fresh state, no transitions
# Act: run status
# Assert: output contains "Escalations: 0"
test_status_contains_escalations_when_zero() {
  echo "test_status_contains_escalations_when_zero_should_show_Escalations_0"

  # Arrange
  bash "$SPIRAL_STATE" init "test-task: escalation count" >/dev/null 2>&1

  # Act
  local output
  output=$(bash "$SPIRAL_STATE" status 2>&1)

  # Assert
  _assert_contains \
    "summary line contains 'Escalations: 0'" \
    "$output" \
    "Escalations: 0"

  # Cleanup for next test
  rm "$STATE_FILE"
}

# test_status_shows_escalation_count_after_one_escalate_transition
# Arrange: init state, add one transition with type=escalate via update --type escalate
# Act: run status
# Assert: output contains "Escalations: 1"
test_status_shows_escalation_count_after_one_escalate_transition() {
  echo "test_status_shows_escalation_count_after_one_escalate_transition_should_show_Escalations_1"

  # Arrange
  bash "$SPIRAL_STATE" init "test-task: escalation count" >/dev/null 2>&1
  bash "$SPIRAL_STATE" update spec_composite running >/dev/null 2>&1
  bash "$SPIRAL_STATE" update spec_composite completed --type escalate >/dev/null 2>&1

  # Act
  local output
  output=$(bash "$SPIRAL_STATE" status 2>&1)

  # Assert
  _assert_contains \
    "summary line contains 'Escalations: 1'" \
    "$output" \
    "Escalations: 1"

  # Cleanup for next test
  rm "$STATE_FILE"
}

# test_status_shows_escalation_count_after_multiple_escalate_transitions
# Arrange: init state, add two escalate transitions
# Act: run status
# Assert: output contains "Escalations: 2"
test_status_shows_escalation_count_after_multiple_escalate_transitions() {
  echo "test_status_shows_escalation_count_after_multiple_escalate_transitions_should_show_Escalations_2"

  # Arrange
  bash "$SPIRAL_STATE" init "test-task: escalation count" >/dev/null 2>&1
  bash "$SPIRAL_STATE" update spec_composite completed --type escalate >/dev/null 2>&1
  bash "$SPIRAL_STATE" update dev_composite completed --type escalate >/dev/null 2>&1
  bash "$SPIRAL_STATE" update ship_composite completed >/dev/null 2>&1

  # Act
  local output
  output=$(bash "$SPIRAL_STATE" status 2>&1)

  # Assert
  _assert_contains \
    "summary line contains 'Escalations: 2'" \
    "$output" \
    "Escalations: 2"

  # Cleanup for next test
  rm "$STATE_FILE"
}

# test_status_summary_line_format
# Arrange: init state, one escalate transition
# Act: run status
# Assert: summary line contains all four fields in expected order
test_status_summary_line_format() {
  echo "test_status_summary_line_format_should_contain_policy_current_regressions_escalations"

  # Arrange
  bash "$SPIRAL_STATE" init "test-task: format check" >/dev/null 2>&1
  bash "$SPIRAL_STATE" update spec_composite running --type escalate >/dev/null 2>&1

  # Act
  local output
  output=$(bash "$SPIRAL_STATE" status 2>&1)

  # Assert: summary line must have all four segments
  _assert_contains \
    "summary line contains 'Policy:'" \
    "$output" \
    "Policy:"

  _assert_contains \
    "summary line contains 'Current:'" \
    "$output" \
    "Current:"

  _assert_contains \
    "summary line contains 'Regressions:'" \
    "$output" \
    "Regressions:"

  _assert_contains \
    "summary line contains 'Escalations:'" \
    "$output" \
    "Escalations:"

  # Cleanup for next test
  rm "$STATE_FILE"
}

# ─── Run all tests ───

echo "=== Test Suite: spiral-state.sh status escalation count ==="
echo ""

_setup

test_status_contains_escalations_when_zero
echo ""
test_status_shows_escalation_count_after_one_escalate_transition
echo ""
test_status_shows_escalation_count_after_multiple_escalate_transitions
echo ""
test_status_summary_line_format

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

[[ "$FAIL" -eq 0 ]]

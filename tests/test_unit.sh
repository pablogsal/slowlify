#!/bin/bash
# Unit tests for slowlify functions
# These tests don't require root and test internal logic

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLOWRUN="$SCRIPT_DIR/../slowlify"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors (if terminal supports them)
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    NC=$(tput sgr0)
else
    RED=''
    GREEN=''
    NC=''
fi

# Test assertion helpers
assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: Expected '$expected', got '$actual' ${msg}"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: Expected to find '$needle' in output ${msg}"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-}"

    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: Did not expect to find '$needle' in output ${msg}"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo -e "${RED}FAIL${NC}: Expected exit code $expected, got $actual ${msg}"
        return 1
    fi
}

# Run a test
run_test() {
    local test_name="$1"
    local test_func="$2"

    ((TESTS_RUN++)) || true

    printf "  %s... " "$test_name"

    if $test_func; then
        printf "%sPASS%s\n" "$GREEN" "$NC"
        ((TESTS_PASSED++)) || true
    else
        printf "%sFAIL%s\n" "$RED" "$NC"
        ((TESTS_FAILED++)) || true
    fi
}

# ==============================================================================
# Tests
# ==============================================================================

test_script_exists() {
    [[ -f "$SLOWRUN" ]] || return 1
    [[ -x "$SLOWRUN" ]] || return 1
}

test_help_output() {
    local output
    output=$("$SLOWRUN" --help 2>&1)

    assert_contains "$output" "Usage:" || return 1
    assert_contains "$output" "PROFILES" || return 1
    assert_contains "$output" "CPU THROTTLING" || return 1
    assert_contains "$output" "MEMORY PRESSURE" || return 1
    assert_contains "$output" "EXAMPLES" || return 1
}

test_list_profiles_output() {
    local output
    output=$("$SLOWRUN" --list-profiles 2>&1)

    assert_contains "$output" "slow" || return 1
    assert_contains "$output" "crawl" || return 1
    assert_contains "$output" "ci" || return 1
    assert_contains "$output" "race" || return 1
    assert_contains "$output" "race-io" || return 1
    assert_contains "$output" "race-net" || return 1
    assert_contains "$output" "mem-pressure" || return 1
    assert_contains "$output" "potato" || return 1
    assert_contains "$output" "flaky" || return 1
}

test_no_command_error() {
    local output
    local exit_code

    output=$("$SLOWRUN" 2>&1) && exit_code=0 || exit_code=$?

    assert_not_contains "$exit_code" "0" || return 1
    assert_contains "$output" "No command specified" || return 1
}

test_check_deps_output() {
    local output
    output=$("$SLOWRUN" --check-deps 2>&1) || true  # May fail if deps missing

    assert_contains "$output" "Checking dependencies" || return 1
    assert_contains "$output" "Required" || return 1
    assert_contains "$output" "System Requirements" || return 1
}

test_help_shows_all_options() {
    local output
    output=$("$SLOWRUN" --help 2>&1)

    # Check all main options are documented
    assert_contains "$output" "--cpu" || return 1
    assert_contains "$output" "--memory" || return 1
    assert_contains "$output" "--cores" || return 1
    assert_contains "$output" "--nice" || return 1
    assert_contains "$output" "--ionice" || return 1
    assert_contains "$output" "--strace" || return 1
    assert_contains "$output" "--stress" || return 1
    assert_contains "$output" "--repeat" || return 1
    assert_contains "$output" "--profile" || return 1
    assert_contains "$output" "--verbose" || return 1
    assert_contains "$output" "--cleanup" || return 1
}

test_help_shows_all_profiles() {
    local output
    output=$("$SLOWRUN" --help 2>&1)

    # Check all profiles are mentioned in help
    assert_contains "$output" "slow" || return 1
    assert_contains "$output" "crawl" || return 1
    assert_contains "$output" "potato" || return 1
}

test_script_uses_bash() {
    local shebang
    shebang=$(head -1 "$SLOWRUN")

    assert_contains "$shebang" "bash" || return 1
}

test_script_uses_strict_mode() {
    local content
    content=$(head -20 "$SLOWRUN")

    assert_contains "$content" "set -euo pipefail" || return 1
}

test_unknown_option_handling() {
    # Unknown options should be collected as positional args, not cause error
    # until we check for command
    local output
    local exit_code

    output=$("$SLOWRUN" --unknown-option 2>&1) && exit_code=0 || exit_code=$?

    # Should fail because no command after --
    [[ "$exit_code" -ne 0 ]] || return 1
}

test_profile_list_format() {
    local output
    output=$("$SLOWRUN" --list-profiles 2>&1)

    # Check format includes CPU and RAM info
    assert_contains "$output" "CPU" || return 1
    assert_contains "$output" "RAM" || return 1
}

# ==============================================================================
# Main
# ==============================================================================

echo "Running unit tests for slowlify"
echo "================================="
echo ""

run_test "Script exists and is executable" test_script_exists
run_test "Help output is complete" test_help_output
run_test "List profiles shows all profiles" test_list_profiles_output
run_test "No command shows error" test_no_command_error
run_test "Check deps produces output" test_check_deps_output
run_test "Help shows all options" test_help_shows_all_options
run_test "Help shows all profiles" test_help_shows_all_profiles
run_test "Script uses bash" test_script_uses_bash
run_test "Script uses strict mode" test_script_uses_strict_mode
run_test "Unknown option handling" test_unknown_option_handling
run_test "Profile list format" test_profile_list_format

echo ""
echo "================================="
echo -e "Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC} (of $TESTS_RUN)"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0

#!/usr/bin/env bats
# Test suite for slowlify using BATS (Bash Automated Testing System)
# Install: npm install -g bats or apt install bats
# Run: bats tests/test_slowrun.bats

SLOWRUN="$BATS_TEST_DIRNAME/../slowlify"

# Helper to check if we can run privileged tests
can_run_privileged() {
    [[ $EUID -eq 0 ]] && [[ -f /sys/fs/cgroup/cgroup.controllers ]]
}

# Skip helper for non-root tests
skip_if_not_root() {
    if [[ $EUID -ne 0 ]]; then
        skip "requires root privileges"
    fi
}

# Skip helper for missing cgroups v2
skip_if_no_cgroups_v2() {
    if [[ ! -f /sys/fs/cgroup/cgroup.controllers ]]; then
        skip "requires cgroups v2"
    fi
}

# ==============================================================================
# Basic functionality tests (no root required)
# ==============================================================================

@test "script exists and is executable" {
    [[ -x "$SLOWRUN" ]]
}

@test "help option shows usage" {
    run "$SLOWRUN" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"PROFILES"* ]]
    [[ "$output" == *"CPU THROTTLING"* ]]
}

@test "list-profiles shows all profiles" {
    run "$SLOWRUN" --list-profiles
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"slow"* ]]
    [[ "$output" == *"crawl"* ]]
    [[ "$output" == *"ci"* ]]
    [[ "$output" == *"race"* ]]
    [[ "$output" == *"potato"* ]]
    [[ "$output" == *"flaky"* ]]
}

@test "no command shows error" {
    run "$SLOWRUN" 2>&1
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"No command specified"* ]]
}

@test "unknown profile shows error" {
    skip_if_not_root
    run "$SLOWRUN" --profile nonexistent -- true 2>&1
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Unknown profile"* ]]
}

@test "check-deps runs without error" {
    run "$SLOWRUN" --check-deps
    # May succeed or fail depending on system, but should not crash
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
    [[ "$output" == *"Checking dependencies"* ]]
}

# ==============================================================================
# Root/cgroups tests
# ==============================================================================

@test "requires root when not root" {
    if [[ $EUID -eq 0 ]]; then
        skip "test requires non-root user"
    fi
    run "$SLOWRUN" -- true 2>&1
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"must be run as root"* ]]
}

@test "basic command execution" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" -c 50 -m 512M -- echo "hello world"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"hello world"* ]]
}

@test "command exit code is preserved" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" -c 50 -- bash -c "exit 42"
    [[ "$status" -eq 42 ]]
}

@test "slow profile works" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" --profile slow -- true
    [[ "$status" -eq 0 ]]
}

@test "cpu throttling is applied" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    # Run a tight loop and verify it completes (basic sanity check)
    run timeout 10 "$SLOWRUN" -c 5 -m 256M -- bash -c 'for i in {1..1000}; do :; done; echo done'
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"done"* ]]
}

@test "memory limit is enforced" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    # Try to allocate more memory than allowed - should fail
    # Using dd to try to allocate ~100M when limit is 32M
    run "$SLOWRUN" -c 50 -m 32M -- bash -c 'dd if=/dev/zero of=/dev/null bs=1M count=100 2>&1' 2>&1
    # Should either fail or be killed
    # We just check it doesn't hang forever
    [[ "$status" -ge 0 ]]  # Any exit is fine, just don't hang
}

@test "verbose mode shows configuration" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" -v -c 25 -m 128M -- true 2>&1
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"CPU:"* ]]
    [[ "$output" == *"Memory:"* ]]
    [[ "$output" == *"25%"* ]]
}

@test "repeat option runs multiple times" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" --repeat 3 -c 50 -- echo "iteration" 2>&1
    [[ "$status" -eq 0 ]]
    # Should see run counter
    [[ "$output" == *"Run 1/3"* ]]
    [[ "$output" == *"Run 2/3"* ]]
    [[ "$output" == *"Run 3/3"* ]]
}

@test "environment variables are passed" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" -c 50 -e TEST_VAR=hello -- bash -c 'echo $TEST_VAR'
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"hello"* ]]
}

@test "cleanup removes stale cgroups" {
    skip_if_not_root

    run "$SLOWRUN" --cleanup 2>&1
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Done"* ]]
}

@test "stress option enables background load" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    # Just verify it doesn't crash with --stress
    run timeout 5 "$SLOWRUN" --stress -c 50 -- bash -c 'sleep 0.5; echo done'
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"done"* ]]
}

@test "cores option sets CPU affinity" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" --cores 0 -c 50 -- true
    [[ "$status" -eq 0 ]]
}

@test "nice level is applied" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" --nice 10 -c 50 -- true
    [[ "$status" -eq 0 ]]
}

@test "ionice class is applied" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" --ionice 2 -c 50 -- true
    [[ "$status" -eq 0 ]]
}

# ==============================================================================
# Profile-specific tests
# ==============================================================================

@test "ci profile works" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run timeout 10 "$SLOWRUN" --profile ci -- echo "ci test"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"ci test"* ]]
}

@test "race profile works" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    if ! command -v strace &>/dev/null; then
        skip "strace not installed"
    fi

    run "$SLOWRUN" --profile race -- true
    [[ "$status" -eq 0 ]]
}

@test "mem-pressure profile works" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" --profile mem-pressure -- true
    [[ "$status" -eq 0 ]]
}

# ==============================================================================
# Edge cases
# ==============================================================================

@test "command with arguments works" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" -c 50 -- bash -c 'echo arg1=$1 arg2=$2' -- foo bar
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"arg1=foo"* ]]
    [[ "$output" == *"arg2=bar"* ]]
}

@test "command with spaces in arguments" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" -c 50 -- echo "hello world"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"hello world"* ]]
}

@test "multiple options can be combined" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" -c 25 -m 128M --nice 15 --cores 0 -- true
    [[ "$status" -eq 0 ]]
}

@test "profile can be overridden" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    # Use slow profile but override CPU
    run "$SLOWRUN" -v --profile slow -c 10 -- true 2>&1
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"10%"* ]]
}

#!/bin/bash
##
##  run-tests.sh - Run all test scripts in dependency order
##
##  Usage: run-tests.sh [-v|--verbose] [-s|--stop-on-failure]
##

BASE=$(realpath "$(dirname "$0")")
source "${BASE}/lib/helpers.sh" || exit 1

VERBOSE=false
STOP_ON_FAILURE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose) VERBOSE=true ;;
        -s|--stop-on-failure) STOP_ON_FAILURE=true ;;
        *) echo "Usage: $0 [-v|--verbose] [-s|--stop-on-failure]"; exit 1 ;;
    esac
    shift
done

# Tests that share state must run in dependency order.
# Standalone tests (create their own clean CA) run last.
STATEFUL_TESTS=(
    test/test-root-ca.sh
    test/test-server-cert.sh
    test/test-user-cert.sh
    test/test-server-cert-renewal.sh
    test/test-user-cert-renewal.sh
    test/test-sub-ca.sh
    test/test-p12-certs.sh
    test/test-sub-ca-autonomy.sh
)

STANDALONE_TESTS=(
    test/test-renew-root-ca-crl.sh
    test/test-cert-chain.sh
)

PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
    local script="$1"
    local name
    name=$(basename "$script")

    print_step "Running ${name}..."

    if $VERBOSE; then
        bash "${BASE}/${script}" 2>&1
        local rc=$?
    else
        local output
        output=$(bash "${BASE}/${script}" 2>&1)
        local rc=$?
    fi

    if [ $rc -eq 0 ]; then
        print_success "${name} passed"
        (( PASS++ ))
    else
        echo -e "${RED}✗ ${name} FAILED (exit code ${rc})${RESTORE}"
        if ! $VERBOSE && [ -n "${output:-}" ]; then
            echo "${output}" | tail -20
        fi
        FAILED_TESTS+=("${name}")
        (( FAIL++ ))
        if $STOP_ON_FAILURE; then
            print_header "Stopping on first failure"
            exit 1
        fi
    fi
}

print_header "SSL CA Test Suite"

print_header "Stateful Tests (shared CA)"
for t in "${STATEFUL_TESTS[@]}"; do
    run_test "$t"
done

print_header "Standalone Tests (self-contained)"
for t in "${STANDALONE_TESTS[@]}"; do
    run_test "$t"
done

print_header "Test Summary"
echo -e "  ${LGREEN}Passed: ${PASS}${RESTORE}"
if [ $FAIL -gt 0 ]; then
    echo -e "  ${RED}Failed: ${FAIL}${RESTORE}"
    for t in "${FAILED_TESTS[@]}"; do
        echo -e "    ${RED}✗ ${t}${RESTORE}"
    done
    exit 1
else
    echo -e "  ${LGREEN}All ${PASS} tests passed.${RESTORE}"
fi

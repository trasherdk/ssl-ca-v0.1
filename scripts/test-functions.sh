#!/bin/bash
##
## test-functions.sh - Common test helper functions
##

# Print a test section header
print_header() {
    echo -e "\n=== $1 ===\n"
}

# Print a test step
print_step() {
    echo "-> $1"
}

# Print an error message and exit
print_error() {
    echo "✗ $1"
    exit 1
}

# Print a success message
print_success() {
    echo "✓ $1"
}

# Assert that string contains substring
assert_contains() {
    local output="$1"
    local expected="$2"
    local message="$3"
    
    if [[ "${output}" == *"${expected}"* ]]; then
        return 0
    else
        echo "❌ Assertion failed: ${message}"
        echo "Expected output to contain: ${expected}"
        echo "Actual output: ${output}"
        exit 1
    fi
}

# Assert that string does not contain substring
assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    local message="$3"
    
    if [[ "${output}" != *"${unexpected}"* ]]; then
        return 0
    else
        echo "❌ Assertion failed: ${message}"
        echo "Expected output NOT to contain: ${unexpected}"
        echo "Actual output: ${output}"
        exit 1
    fi
}

# Assert that two strings are equal
assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    
    if [ "${actual}" == "${expected}" ]; then
        return 0
    else
        echo "❌ Assertion failed: ${message}"
        echo "Expected: ${expected}"
        echo "Actual: ${actual}"
        exit 1
    fi
}

# Assert that a command succeeds (returns 0)
assert_success() {
    local command="$1"
    local message="$2"
    
    if eval "${command}"; then
        return 0
    else
        echo "❌ Assertion failed: ${message}"
        echo "Command failed: ${command}"
        exit 1
    fi
}

# Assert that a command fails (returns non-zero)
assert_failure() {
    local command="$1"
    local message="$2"
    
    if ! eval "${command}"; then
        return 0
    else
        echo "❌ Assertion failed: ${message}"
        echo "Command succeeded but should have failed: ${command}"
        exit 1
    fi
}

#!/bin/bash
##
##  test-p12-certs.sh - Test PKCS#12 certificate operations
##

# Source helper functions
if [ "$(basename $(dirname $0))" = "test" ]; then
    BASE=$(realpath $(dirname $0)/..)
else
    BASE=$(realpath $(dirname $0))
fi

cd "${BASE}" || exit 1

source "${BASE}/lib/helpers.sh" || exit 1
export CRL_URL="${CRL_URL:-http://crl.example.test/root-ca.crl.pem}"

TEST_DIR="${BASE}/test-environment"

# Export one PKCS#12 file. password may be empty.
export_p12() {
    local script="$1"
    local name="$2"
    local password="$3"
    local log_name="$4"
    local test_pipe="${TEST_DIR}/test_pipe_${log_name}"

    mkfifo "$test_pipe"
    tee "${TEST_DIR}/${log_name}.log" < "$test_pipe" &
    local tee_pid=$!

    expect <<EOF >> "${test_pipe}"
        log_user 1
        set timeout 60
        spawn ${script} ${name}
        expect {
            "Export password (empty for none):" {
                send "${password}\r"
                exp_continue
            }
            "Failed to verify PKCS#12 file" {
                puts "\nError: PKCS#12 verify failed"
                exit 1
            }
            timeout {
                puts "\nTimeout waiting for prompt"
                exit 1
            }
            eof
        }
EOF
    local result=$?
    wait "$tee_pid"
    rm -f "$test_pipe"
    if [ "$result" -ne 0 ]; then
        print_error "PKCS#12 export failed. Check ${TEST_DIR}/${log_name}.log for details."
    fi
}

verify_p12() {
    local p12_path="$1"
    local password="$2"
    local log_path="$3"

    openssl pkcs12 -in "${p12_path}" -info -nodes -passin "pass:${password}" > "${log_path}" 2>&1
    if [ $? -ne 0 ]; then
        print_error "Failed to verify PKCS#12 contents"
    fi
    if ! grep -q "PRIVATE KEY" "${log_path}"; then
        print_error "Private key not found in PKCS#12 file"
    fi
    if ! grep -q "CERTIFICATE" "${log_path}"; then
        print_error "Certificate not found in PKCS#12 file"
    fi
}

# Create test environment
print_header "Setting up test environment"
if [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
fi
mkdir -p "${TEST_DIR}"

# Test server certificate p12 export
test_server_p12() {
    local server_name="test-server.com"
    print_header "Testing Server Certificate PKCS#12 Export"

    # Create a server certificate first
    print_step "Creating test server certificate..."
    "${BASE}/test/test-server-cert.sh" &> "${TEST_DIR}/server-cert.log"
    if [ $? -ne 0 ]; then
        print_error "Failed to create server certificate"
    fi

    print_step "Testing PKCS#12 export with a password..."
    export_p12 "${BASE}/server-p12.sh" "${server_name}" "testpass" "server-p12-pass"
    verify_p12 "${BASE}/certs/${server_name}/${server_name}.p12" "testpass" "${TEST_DIR}/server-p12-pass-verify.log"

    print_step "Testing PKCS#12 export with an empty password..."
    export_p12 "${BASE}/server-p12.sh" "${server_name}" "" "server-p12-empty"
    verify_p12 "${BASE}/certs/${server_name}/${server_name}.p12" "" "${TEST_DIR}/server-p12-empty-verify.log"

    print_success "Server certificate PKCS#12 export test passed"
}

# Test user certificate p12 export
test_user_p12() {
    local user_email="test-user@example.com"
    print_header "Testing User Certificate PKCS#12 Export"

    # Create a user certificate first
    print_step "Creating test user certificate..."
    "${BASE}/test/test-user-cert.sh" &> "${TEST_DIR}/user-cert.log"
    if [ $? -ne 0 ]; then
        print_error "Failed to create user certificate. Check ${TEST_DIR}/user-cert.log for details."
    fi
    print_success "User certificate creation successful."

    print_step "Testing PKCS#12 export with an empty password..."
    export_p12 "${BASE}/user-p12.sh" "${user_email}" "" "user-p12-empty"
    verify_p12 "${BASE}/certs/users/${user_email}/${user_email}.p12" "" "${TEST_DIR}/user-p12-empty-verify.log"

    print_step "Testing PKCS#12 export with a password..."
    export_p12 "${BASE}/user-p12.sh" "${user_email}" "testpass" "user-p12-pass"
    verify_p12 "${BASE}/certs/users/${user_email}/${user_email}.p12" "testpass" "${TEST_DIR}/user-p12-pass-verify.log"

    print_success "User certificate PKCS#12 export test passed"
}

# Run tests
test_server_p12
test_user_p12

print_header "Test Summary"
print_success "All PKCS#12 certificate tests passed successfully!"

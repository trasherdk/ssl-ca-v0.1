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

# Test environment setup
TEST_DIR="${BASE}/test-environment"
TEST_PASSPHRASE="testpass"
export TEST_PASSPHRASE

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
    "${BASE}/test-server-cert.sh" &> "${TEST_DIR}/server-cert.log"
    if [ $? -ne 0 ]; then
        print_error "Failed to create server certificate"
    fi

    # Create test pipe
    test_pipe="${TEST_DIR}/test_pipe_server_p12"
    mkfifo "$test_pipe"

    # Start logging in background
    tee "${TEST_DIR}/server-p12.log" < "$test_pipe" &
    TEE_PID=$!

    # Export to PKCS#12
    print_step "Testing PKCS#12 export..."
    expect <<EOF >> "${test_pipe}"
        log_user 1
        set timeout 60
        spawn ${BASE}/server-p12.sh ${server_name}
        expect {
            "Enter Export Password:" {
                send "${TEST_PASSPHRASE}\r"
                exp_continue
            }
            "Verifying - Enter Export Password:" {
                send "${TEST_PASSPHRASE}\r"
                exp_continue
            }
            "Error*" {
                puts "\n${RED}Error: Server certificate export failed${RESTORE}"
                exit 1
            }
            timeout {
                puts "\nTimeout waiting for prompt"
                exit 1
            }
            eof
        }
EOF
RESULT=$?

    if [ $RESULT -ne 0 ]; then
        print_error "Server certificate export failed. Check ${TEST_DIR}/server-p12.log for details."
    fi

    print_success "Server certificate export successful."

    # Clean up
    wait $TEE_PID
    rm -f "$test_pipe"

    # Verify the p12 file exists
    if [ ! -f "${BASE}/certs/${server_name}/${server_name}.p12" ]; then
        print_error "PKCS#12 file not created"
    fi

    # Verify p12 contents
    print_step "Verifying PKCS#12 contents..."
    openssl pkcs12 -in "${BASE}/certs/${server_name}/${server_name}.p12" -info -nodes -passin "pass:${TEST_PASSPHRASE}" &> "${TEST_DIR}/server-p12-verify.log"
    if [ $? -ne 0 ]; then
        print_error "Failed to verify PKCS#12 contents"
    fi

    # Check if private key is included
    if ! grep -q "PRIVATE KEY" "${TEST_DIR}/server-p12-verify.log"; then
        print_error "Private key not found in PKCS#12 file"
    fi

    # Check if certificate is included
    if ! grep -q "CERTIFICATE" "${TEST_DIR}/server-p12-verify.log"; then
        print_error "Certificate not found in PKCS#12 file"
    fi

    print_success "Server certificate PKCS#12 export test passed"
}

# Test user certificate p12 export
test_user_p12() {
    local user_email="test-user@example.com"
    print_header "Testing User Certificate PKCS#12 Export"

    # Create a user certificate first
    print_step "Creating test user certificate..."
    "${BASE}/test-user-cert.sh" &> "${TEST_DIR}/user-cert.log"
    if [ $? -ne 0 ]; then
        print_error "Failed to create user certificate. Check ${TEST_DIR}/user-cert.log for details."
    fi
    print_success "User certificate creation successful."

    # Create test pipe
    test_pipe="${TEST_DIR}/test_pipe_user_p12"
    mkfifo "$test_pipe"

    # Start logging in background
    tee "${TEST_DIR}/user-p12.log" < "$test_pipe" &
    TEE_PID=$!

    # Export to PKCS#12
    print_step "Testing PKCS#12 export..."
    expect <<EOF >> "${test_pipe}"
        log_user 1
        set timeout 60
        spawn ${BASE}/user-p12.sh ${user_email}
        expect {
            "Enter Export Password:" {
                send "${TEST_PASSPHRASE}\r"
                exp_continue
            }
            "Verifying - Enter Export Password:" {
                send "${TEST_PASSPHRASE}\r"
                exp_continue
            }
            "Error*" {
                puts "\n${RED}Error: User certificate export failed${RESTORE}"
                exit 1
            }
            timeout {
                puts "\nTimeout waiting for prompt"
                exit 1
            }
            eof
        }
EOF
RESULT=$?

    if [ $RESULT -ne 0 ]; then
        print_error "User certificate export failed. Check ${TEST_DIR}/user-p12.log for details."
    fi

    print_success "User certificate export successful."

    # Clean up
    wait $TEE_PID
    rm -f "$test_pipe"

    # Verify the p12 file exists
    if [ ! -f "${BASE}/certs/users/${user_email}/${user_email}.p12" ]; then
        print_error "PKCS#12 file not created"
    fi

    # Verify p12 contents
    print_step "Verifying PKCS#12 contents..."
    openssl pkcs12 -in "${BASE}/certs/users/${user_email}/${user_email}.p12" -info -nodes -passin "pass:${TEST_PASSPHRASE}" &> "${TEST_DIR}/user-p12-verify.log"
    if [ $? -ne 0 ]; then
        print_error "Failed to verify PKCS#12 contents"
    fi

    # Check if private key is included
    if ! grep -q "PRIVATE KEY" "${TEST_DIR}/user-p12-verify.log"; then
        print_error "Private key not found in PKCS#12 file"
    fi

    # Check if certificate is included
    if ! grep -q "CERTIFICATE" "${TEST_DIR}/user-p12-verify.log"; then
        print_error "Certificate not found in PKCS#12 file"
    fi

    print_success "User certificate PKCS#12 export test passed"
}

# Run tests
test_server_p12
test_user_p12

print_header "Test Summary"
print_success "All PKCS#12 certificate tests passed successfully!"

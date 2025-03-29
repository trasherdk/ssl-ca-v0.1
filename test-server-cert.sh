#!/bin/bash
##
## test-server-cert.sh - Test Server Certificate creation and signing
##

BASE=$(realpath $(dirname $0))
TEST_DIR="${BASE}/test-environment"
SERVER_NAME="test-server.com"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing Server Certificate creation"

# Make sure test environment exists
if [ ! -d "${TEST_DIR}" ]; then
    mkdir -p "${TEST_DIR}"
fi

print_step "Testing Server Certificate creation"

test_pipe="${TEST_DIR}/test_pipe_server_cert"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/server-cert.log" < "$test_pipe" &
TEE_PID=$!

expect <<EOF > "$test_pipe" 2>&1
log_user 1
set timeout 60
spawn "${BASE}/new-server-cert.sh" "${SERVER_NAME}" "www.${SERVER_NAME}"
expect {
    "Country Name*" {
        send "DK\r"
        exp_continue
    }
    "State or Province Name*" {
        send "Denmark\r"
        exp_continue
    }
    "Locality Name*" {
        send "Copenhagen\r"
        exp_continue
    }
    "Organization Name*" {
        send "Test Organization\r"
        exp_continue
    }
    "Organizational Unit Name*" {
        send "Server Certificates\r"
        exp_continue
    }
    "Common Name*" {
        send "${SERVER_NAME}\r"
        exp_continue
    }
    "Email Address*" {
        send "hostmaster@fumlersoft.dk\r"
        exp_continue
    }
    "Error*" {
        puts "\n${RED}Error: Server certificate creation failed${RESTORE}"
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
    print_error "new-server-cert.sh failed. Aborting test."
    exit 1
else
    print_success "Server certificate creation script executed successfully: ${RESULT}"
fi

# Clean up the pipe and background process
wait $TEE_PID
rm "$test_pipe"

# Check if the CSR was created
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.csr" ]; then
    print_error "Server certificate creation failed. Check ${TEST_DIR}/server-cert.log for details."
fi

print_success "Server certificate creation successful."

print_step "Testing Server Certificate signing..."

test_pipe="${TEST_DIR}/test_pipe_server_cert"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/server-cert.log" < "$test_pipe" &
TEE_PID=$!

expect <<EOF >> "${test_pipe}" 2>&1
log_user 1
set timeout 60
spawn "${BASE}/sign-server-cert.sh" "${SERVER_NAME}" "www.${SERVER_NAME}"
expect {
"Enter pass phrase for*" {
    send "${TEST_PASSPHRASE}\r"
    exp_continue
    }
    "Sign the certificate*" {
        send "y\r"
        exp_continue
    }
    "1 out of 1 certificate requests certified*" {
        send "y\r"
        exp_continue
    }
    "Error*" {
        puts "\n${RED}Error: Server certificate signing failed${RESTORE}"
        exit 1
    }
    "Timeout*" {
        puts "\nTimeout waiting for prompt"
        exit 1
    }
    expect eof
}
EOF
RESULT=$?

if [ $RESULT -ne 0 ]; then
    print_error "Server certificate signing failed. Check ${TEST_DIR}/server-cert.log for details."
else
    print_success "Server certificate signing executed successfully: ${RESULT}"
fi

# Clean up the pipe and background process
wait $TEE_PID
rm "$test_pipe"

# Check if the certificate was created
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" ]; then
    print_error "Server certificate signing failed. Check ${TEST_DIR}/server-cert.log for details."
fi

print_success "Server certificate signing successful."

# Verify Server Certificate structure
print_step "Verifying Server Certificate structure..."
openssl x509 -in "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" -text -noout > "${TEST_DIR}/server-cert-verify.log" 2>&1
if [ $? -ne 0 ]; then
    print_error "Server certificate verification failed. Check ${TEST_DIR}/server-cert-verify.log for details."
fi

print_success "Server certificate structure verified successfully."

# Verify Server Certificate chain
print_step "Verifying Server Certificate chain..."
openssl verify -CAfile "${BASE}/CA/ca.crt" "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" > "${TEST_DIR}/server-cert-chain.log" 2>&1
if [ $? -ne 0 ]; then
    print_error "Server certificate chain verification failed. Check ${TEST_DIR}/server-cert-chain.log for details."
fi

print_success "Server certificate chain verified successfully."

print_success "All Server Certificate tests passed successfully."
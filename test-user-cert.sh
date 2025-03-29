#!/bin/bash
##
## test-user-cert.sh - Test User Certificate creation and signing
##

BASE=$(realpath $(dirname $0))
TEST_DIR="${BASE}/test-environment"
USER_EMAIL="test-user@example.com"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing User Certificate creation"

# Make sure test environment exists
if [ ! -d "${TEST_DIR}" ]; then
    mkdir -p "${TEST_DIR}"
fi

test_pipe="${TEST_DIR}/test_pipe_user_cert"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/user-cert.log" < "$test_pipe" &
TEE_PID=$!

# Add debugging output to the expect script for User Certificate creation
expect <<EOF > "$test_pipe" 2>&1
log_user 1
spawn "${BASE}/new-user-cert.sh" "${USER_EMAIL}"
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
        send "User Certificates\r"
        exp_continue
    }
    "Common Name*" {
        send "${USER_EMAIL}\r"
        exp_continue
    }
    "Email Address*" {
        send "${USER_EMAIL}\r"
        exp_continue
    }
    "Error*" {
        puts "\n${RED}Error: User certificate creation failed${RESTORE}"
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
    print_error "new-user-cert.sh failed. Aborting test."
fi

print_success "User certificate creation script executed successfully: ${RESULT}"

# Clean up the pipe and background process
wait $TEE_PID
rm "$test_pipe"

# Check if the user certificate signing request (CSR) was created successfully
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.csr" ]; then
    print_error "User certificate creation failed. Check ${TEST_DIR}/user-cert.log for details."
fi

print_success "User certificate creation successful."

print_step "Testing User Certificate signing..."

test_pipe="${TEST_DIR}/test_pipe_user_cert"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/user-cert.log" < "$test_pipe" &
TEE_PID=$!

expect <<EOF >> "${test_pipe}" 2>&1
log_user 1
set timeout 60
spawn "${BASE}/sign-user-cert.sh" "${USER_EMAIL}"
expect {
    "Enter pass phrase*" {
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
        puts "\n${RED}Error: User certificate signing failed${RESTORE}"
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
    print_error "User certificate signing failed. Check ${TEST_DIR}/user-cert.log for details."
fi

print_success "User certificate signing successful."

# Clean up the pipe and background process
wait $TEE_PID
rm "$test_pipe"

# Check if the certificate was created
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" ]; then
    print_error "User certificate signing failed. Check ${TEST_DIR}/user-cert.log for details."
fi

# Check if the certificate was signed
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" ]; then
    print_error "User certificate signing failed. Check ${TEST_DIR}/user-cert.log for details."
fi

print_success "User certificate signed successfully."

# Verify User Certificate structure
print_step "Verifying User Certificate structure..."
openssl x509 -in "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" -text -noout > "${TEST_DIR}/user-cert-verify.log" 2>&1
if [ $? -ne 0 ]; then
    print_error "User certificate verification failed. Check ${TEST_DIR}/user-cert-verify.log for details."
fi
print_success "User certificate structure verified successfully."

# Verify User Certificate chain
print_step "Verifying User Certificate chain..."
openssl verify -CAfile "${BASE}/CA/ca.crt" "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" > "${TEST_DIR}/user-cert-chain.log" 2>&1
if [ $? -ne 0 ]; then
    print_error "User certificate chain verification failed. Check ${TEST_DIR}/user-cert-chain.log for details."
fi
print_success "User certificate chain verified successfully."

print_success "All User Certificate tests passed successfully."

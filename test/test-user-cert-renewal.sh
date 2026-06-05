#!/bin/bash
##
##  test-user-cert-renewal.sh - Test user certificate renewal
##

BASE=$(realpath "$(dirname "$0")/..")
TEST_DIR="${BASE}/test-environment"
USER_EMAIL="test-user@example.com"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing User Certificate Renewal"

if [ ! -d "${TEST_DIR}" ]; then
    mkdir -p "${TEST_DIR}"
fi

print_step "Verifying user certificate prerequisites..."
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" ]; then
    print_error "User certificate not found. Run test-user-cert.sh first."
fi

SERIAL_BEFORE=$(openssl x509 -in "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" -noout -serial | cut -d= -f2)
print_step "Serial before renewal: ${SERIAL_BEFORE}"

print_step "Renewing user certificate..."

test_pipe="${TEST_DIR}/test_pipe_renew_user"
mkfifo "$test_pipe"
tee "${TEST_DIR}/renew-user.log" < "$test_pipe" &
TEE_PID=$!

expect <<EOF > "$test_pipe" 2>&1
log_user 1
set timeout 60
spawn "${BASE}/renew-user-cert.sh" "${USER_EMAIL}"
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
    timeout {
        puts "\nTimeout waiting for prompt"
        exit 1
    }
    eof
}
EOF
RESULT=$?

wait $TEE_PID
rm "$test_pipe"

if [ $RESULT -ne 0 ]; then
    print_error "User certificate renewal failed. Check ${TEST_DIR}/renew-user.log for details."
fi

print_step "Verifying renewed user certificate..."
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" ]; then
    print_error "Renewed user certificate not found."
fi

if ! openssl x509 -in "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" -noout > /dev/null 2>&1; then
    print_error "Renewed user certificate is not a valid X.509 certificate."
fi

SERIAL_AFTER=$(openssl x509 -in "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" -noout -serial | cut -d= -f2)
print_step "Serial after renewal: ${SERIAL_AFTER}"
if [ "${SERIAL_BEFORE}" = "${SERIAL_AFTER}" ]; then
    print_error "Certificate serial did not change after renewal."
fi

if ! openssl verify -CAfile "${BASE}/CA/ca.crt" "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" > /dev/null 2>&1; then
    print_error "Renewed user certificate chain validation failed."
fi

if [ ! -d "${BASE}/certs/users/${USER_EMAIL}/backup" ]; then
    print_error "Backup directory not created for user certificate."
fi
if [ -z "$(ls "${BASE}/certs/users/${USER_EMAIL}/backup/")" ]; then
    print_error "No backup file found for old user certificate."
fi

print_success "User certificate renewed successfully (serial ${SERIAL_BEFORE} -> ${SERIAL_AFTER})."

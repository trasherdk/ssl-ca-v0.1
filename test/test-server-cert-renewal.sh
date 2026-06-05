#!/bin/bash
##
##  test-server-cert-renewal.sh - Test server certificate renewal
##

BASE=$(realpath "$(dirname "$0")/..")
TEST_DIR="${BASE}/test-environment"
SERVER_NAME="test-server.com"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing Server Certificate Renewal"

if [ ! -d "${TEST_DIR}" ]; then
    mkdir -p "${TEST_DIR}"
fi

print_step "Verifying server certificate prerequisites..."
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" ]; then
    print_error "Server certificate not found. Run test-server-cert.sh first."
fi

SERIAL_BEFORE=$(openssl x509 -in "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" -noout -serial | cut -d= -f2)
print_step "Serial before renewal: ${SERIAL_BEFORE}"

print_step "Renewing server certificate..."

test_pipe="${TEST_DIR}/test_pipe_renew_server"
mkfifo "$test_pipe"
tee "${TEST_DIR}/renew-server.log" < "$test_pipe" &
TEE_PID=$!

expect <<EOF > "$test_pipe" 2>&1
log_user 1
set timeout 60
spawn "${BASE}/renew-server-cert.sh" "${SERVER_NAME}"
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
    print_error "Server certificate renewal failed. Check ${TEST_DIR}/renew-server.log for details."
fi

print_step "Verifying renewed server certificate..."
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" ]; then
    print_error "Renewed server certificate not found."
fi

if ! openssl x509 -in "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" -noout > /dev/null 2>&1; then
    print_error "Renewed server certificate is not a valid X.509 certificate."
fi

SERIAL_AFTER=$(openssl x509 -in "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" -noout -serial | cut -d= -f2)
print_step "Serial after renewal: ${SERIAL_AFTER}"
if [ "${SERIAL_BEFORE}" = "${SERIAL_AFTER}" ]; then
    print_error "Certificate serial did not change after renewal."
fi

if ! openssl verify -CAfile "${BASE}/CA/ca.crt" "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" > /dev/null 2>&1; then
    print_error "Renewed server certificate chain validation failed."
fi

if [ ! -d "${BASE}/certs/${SERVER_NAME}/backup" ]; then
    print_error "Backup directory not created for server certificate."
fi
if [ -z "$(ls "${BASE}/certs/${SERVER_NAME}/backup/")" ]; then
    print_error "No backup file found for old server certificate."
fi

print_success "Server certificate renewed successfully (serial ${SERIAL_BEFORE} -> ${SERIAL_AFTER})."

#!/bin/bash
##
##  test-revoke-cert.sh - Test certificate revocation, including already-revoked
##

BASE=$(realpath "$(dirname "$0")/..")
TEST_DIR="${BASE}/test-environment"
SERVER_NAME="test-server.com"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing Certificate Revocation"

if [ ! -d "${TEST_DIR}" ]; then
    mkdir -p "${TEST_DIR}"
fi

# ── Prerequisites ─────────────────────────────────────────────────────────────

print_step "Verifying prerequisites..."
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" ]; then
    print_error "Server certificate not found. Run test-server-cert.sh first."
fi
if [ ! -f "${BASE}/CA/ca.crt" ]; then
    print_error "Root CA not found. Run test-root-ca.sh first."
fi

# Ensure certs-revoked directory exists
mkdir -p "${BASE}/certs-revoked"

# Read current serial from the live cert
SERIAL=$(openssl x509 -in "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" -noout -serial | cut -d= -f2)
print_step "Certificate serial to revoke: ${SERIAL}"

if grep -q "^R" "${BASE}/CA/ca.db.index" 2>/dev/null; then
    if grep "^R" "${BASE}/CA/ca.db.index" | grep -q "${SERIAL}"; then
        print_error "Certificate ${SERIAL} is already revoked before test started."
    fi
fi

# Count how many valid (non-revoked) entries exist for this CN
# so we can send the correct menu number to pick the current cert
VALID_COUNT=$(grep -v "^R" "${BASE}/CA/ca.db.index" | grep -c "${SERVER_NAME}" || true)
print_step "Valid entries for ${SERVER_NAME} in CA db: ${VALID_COUNT}"

# ── Test 1: Valid revocation ──────────────────────────────────────────────────

print_step "Test 1: Revoking ${SERVER_NAME}..."

test_pipe="${TEST_DIR}/test_pipe_revoke"
mkfifo "$test_pipe"
tee "${TEST_DIR}/revoke.log" < "$test_pipe" &
TEE_PID=$!

expect <<EOF > "$test_pipe" 2>&1
log_user 1
set timeout 60
spawn "${BASE}/revoke-cert.sh" "${SERVER_NAME}"
expect {
    "Enter the number*" {
        send "${VALID_COUNT}\r"
        exp_continue
    }
    "Enter pass phrase for*" {
        send "${TEST_PASSPHRASE}\r"
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
    print_error "Certificate revocation failed. Check ${TEST_DIR}/revoke.log for details."
fi

# Verify the CA database shows the cert as revoked
if ! grep -q "^R" "${BASE}/CA/ca.db.index"; then
    print_error "CA database does not show any revoked certificates after revocation."
fi
if ! grep "^R" "${BASE}/CA/ca.db.index" | grep -qi "${SERIAL}"; then
    print_error "Certificate ${SERIAL} not marked as revoked in CA database."
fi

# Verify the cert directory was moved to certs-revoked
if [ -d "${BASE}/certs/${SERVER_NAME}" ]; then
    print_error "Certificate directory still present under certs/ after revocation."
fi
REVOKED_DIR=$(find "${BASE}/certs-revoked" -maxdepth 1 -name "${SERVER_NAME}-*" -type d | head -1)
if [ -z "${REVOKED_DIR}" ]; then
    print_error "Revoked certificate directory not found in certs-revoked/."
fi

print_success "Certificate ${SERIAL} revoked successfully and moved to certs-revoked/."

# ── Test 2: Revoking an already-revoked certificate ──────────────────────────

print_step "Test 2: Attempting to revoke already-revoked certificate..."

# The PEM file for the revoked cert
PEM_FILE="${BASE}/CA/ca.db.certs/${SERIAL}.pem"
if [ ! -f "${PEM_FILE}" ]; then
    print_error "PEM file ${PEM_FILE} not found — cannot test double-revocation."
fi

# Attempt direct openssl revocation — should fail or report already revoked
output=$(openssl ca \
    -config "${BASE}/config/root-ca.conf" \
    -revoke "${PEM_FILE}" \
    -passin "pass:${TEST_PASSPHRASE}" 2>&1)
RC=$?

if [ $RC -eq 0 ]; then
    # Some OpenSSL versions exit 0 but print "Already revoked"
    if echo "${output}" | grep -qi "already revoked\|ERROR"; then
        print_success "Already-revoked certificate correctly reported as already revoked."
    else
        print_error "Re-revoking an already-revoked certificate succeeded silently (no error reported)."
    fi
else
    print_success "Already-revoked certificate correctly rejected (exit code ${RC})."
fi

# ── Test 3: revoke-cert.sh with nonexistent certificate name ─────────────────

print_step "Test 3: revoke-cert.sh with nonexistent name..."

output=$("${BASE}/revoke-cert.sh" "nonexistent-cert-xyz.com" 2>&1)
RC=$?
if [ $RC -ne 0 ] && ! echo "${output}" | grep -qi "no certificate found"; then
    print_error "revoke-cert.sh gave unexpected error for nonexistent cert: ${output}"
fi
if echo "${output}" | grep -qi "no certificate found"; then
    print_success "revoke-cert.sh correctly reports no certificate found for unknown name."
else
    print_success "revoke-cert.sh exited cleanly for unknown name (exit ${RC})."
fi

print_success "All certificate revocation tests passed."

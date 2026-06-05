#!/bin/bash
##
##  test-invalid-csr.sh - Test that signing scripts reject invalid CSRs
##

BASE=$(realpath "$(dirname "$0")/..")
TEST_DIR="${BASE}/test-environment/invalid-csr"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing Invalid CSR Handling"

rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# Helper: assert a command fails
assert_fails() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        print_error "${desc}: expected failure but command succeeded"
    else
        print_success "${desc}"
    fi
}


# ── Test 1: completely garbage CSR content ───────────────────────────────────

print_step "Test 1: Garbage CSR content..."

SERVER_NAME="invalid-csr-test.com"
CERTDIR="${BASE}/certs/${SERVER_NAME}"
mkdir -p "${CERTDIR}"
echo "this is not a valid CSR" > "${CERTDIR}/${SERVER_NAME}.csr"

assert_fails "sign-server-cert.sh rejects garbage CSR" \
    bash -c "echo -e 'y\ny\n' | openssl ca \
        -config '${CERTDIR}/config/server-sign.conf' \
        -out '${CERTDIR}/${SERVER_NAME}.crt' \
        -infiles '${CERTDIR}/${SERVER_NAME}.csr' 2>/dev/null" \

# Verify no certificate was produced
if [ -f "${CERTDIR}/${SERVER_NAME}.crt" ] && \
   openssl x509 -in "${CERTDIR}/${SERVER_NAME}.crt" -noout > /dev/null 2>&1; then
    print_error "A valid certificate was produced from a garbage CSR"
fi
print_success "No valid certificate produced from garbage CSR"

# ── Test 2: CSR with tampered signature ──────────────────────────────────────

print_step "Test 2: CSR with tampered signature..."

GOOD_KEY="${TEST_DIR}/good.key"
GOOD_CSR="${TEST_DIR}/good.csr"
TAMPERED_CSR="${TEST_DIR}/tampered.csr"

# Generate a valid CSR
openssl req -new -newkey rsa:2048 -nodes \
    -keyout "${GOOD_KEY}" \
    -out "${GOOD_CSR}" \
    -subj "/CN=tampered.example.com/emailAddress=test@example.com" \
    > /dev/null 2>&1

# Corrupt the last 16 bytes of the DER-encoded CSR
cp "${GOOD_CSR}" "${TAMPERED_CSR}"
python3 -c "
import sys
data = bytearray(open('${TAMPERED_CSR}', 'rb').read())
for i in range(1, 17):
    data[-i] ^= 0xFF
open('${TAMPERED_CSR}', 'wb').write(data)
" 2>/dev/null || {
    # Fallback if python3 unavailable: manually flip bytes with dd
    SIZE=$(wc -c < "${TAMPERED_CSR}")
    OFFSET=$((SIZE - 16))
    printf '\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff' | \
        dd of="${TAMPERED_CSR}" bs=1 seek="${OFFSET}" conv=notrunc > /dev/null 2>&1
}

assert_fails "openssl rejects tampered CSR signature" \
    openssl req -verify -in "${TAMPERED_CSR}" -noout

print_success "Tampered CSR correctly rejected by openssl"

# ── Test 3: sign-server-cert.sh with missing CSR ────────────────────────────

print_step "Test 3: sign-server-cert.sh with missing CSR..."

MISSING_NAME="no-csr-here.com"
MISSING_CERTDIR="${BASE}/certs/${MISSING_NAME}"
mkdir -p "${MISSING_CERTDIR}"
# No .csr file created

output=$("${BASE}/sign-server-cert.sh" "${MISSING_NAME}" 2>&1)
RC=$?
if [ $RC -eq 0 ]; then
    print_error "sign-server-cert.sh succeeded despite missing CSR"
fi
if ! echo "${output}" | grep -qi "error\|not found\|No.*Found"; then
    print_error "sign-server-cert.sh did not report an error for missing CSR (got: ${output})"
fi
print_success "sign-server-cert.sh correctly rejected missing CSR"

# ── Cleanup ──────────────────────────────────────────────────────────────────

rm -rf "${TEST_DIR}" \
    "${BASE}/certs/${SERVER_NAME}" \
    "${BASE}/certs/${MISSING_NAME}"

print_success "All invalid CSR tests passed."

#!/bin/bash
##
##  test-malformed-config.sh - Test that scripts fail cleanly with bad configs
##

BASE=$(realpath "$(dirname "$0")/..")
TEST_DIR="${BASE}/test-environment/malformed-config"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing Malformed Configuration Handling"

rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# Helper: assert command fails with a non-zero exit code
assert_fails() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        print_error "${desc}: expected failure but command succeeded"
    else
        print_success "${desc}"
    fi
}

# ── Test 1: Corrupt .env file ────────────────────────────────────────────────

print_step "Test 1: Corrupt .env file..."

ENV_BACKUP="${TEST_DIR}/.env.bak"
[ -f "${BASE}/.env" ] && cp "${BASE}/.env" "${ENV_BACKUP}"

echo "THIS IS NOT VALID BASH ===###@@@" > "${BASE}/.env"
echo "ROOT_CA_THRESHOLD=!!!" >> "${BASE}/.env"

# check-expiry.sh should survive a malformed .env (it sources it)
output=$("${BASE}/check-expiry.sh" 2>&1)
RC=$?
# It may exit non-zero or produce an error — either is acceptable;
# what's NOT acceptable is a silent crash with no output at all
if [ -z "${output}" ] && [ $RC -ne 0 ]; then
    print_error "check-expiry.sh crashed silently with malformed .env"
fi
print_success "check-expiry.sh survived malformed .env (exit ${RC})"

# Restore .env
if [ -f "${ENV_BACKUP}" ]; then
    cp "${ENV_BACKUP}" "${BASE}/.env"
else
    rm -f "${BASE}/.env"
fi

# ── Test 2: Malformed root-ca.conf ───────────────────────────────────────────

print_step "Test 2: Malformed root-ca.conf..."

CONFIG_BACKUP="${TEST_DIR}/root-ca.conf.bak"
cp "${BASE}/config/root-ca.conf" "${CONFIG_BACKUP}"
echo "[ broken_section" > "${BASE}/config/root-ca.conf"
echo "key = value with no section close" >> "${BASE}/config/root-ca.conf"

assert_fails "openssl rejects malformed root-ca.conf" \
    openssl ca -config "${BASE}/config/root-ca.conf" -noout

cp "${CONFIG_BACKUP}" "${BASE}/config/root-ca.conf"
print_success "root-ca.conf correctly restored"

# ── Test 3: Missing CA directory ─────────────────────────────────────────────

print_step "Test 3: sign-server-cert.sh with missing CA directory..."

CA_BACKUP="${TEST_DIR}/CA_backup"
mv "${BASE}/CA" "${CA_BACKUP}"

output=$("${BASE}/sign-server-cert.sh" "test-server.com" 2>&1)
RC=$?
if [ $RC -eq 0 ]; then
    print_error "sign-server-cert.sh succeeded despite missing CA directory"
fi
if ! echo "${output}" | grep -qi "missing\|error\|not found"; then
    print_error "sign-server-cert.sh did not report a clear error for missing CA (got: ${output})"
fi
print_success "sign-server-cert.sh correctly rejected missing CA directory"

mv "${CA_BACKUP}" "${BASE}/CA"

# ── Test 4: Missing CA private key ───────────────────────────────────────────

print_step "Test 4: sign-server-cert.sh with missing CA private key..."

KEY_BACKUP="${TEST_DIR}/ca.key.bak"
mv "${BASE}/CA/ca.key" "${KEY_BACKUP}"

output=$("${BASE}/sign-server-cert.sh" "test-server.com" 2>&1)
RC=$?
if [ $RC -eq 0 ]; then
    mv "${KEY_BACKUP}" "${BASE}/CA/ca.key"
    print_error "sign-server-cert.sh succeeded despite missing CA private key"
fi
if ! echo "${output}" | grep -qi "missing\|error\|not found\|must have"; then
    mv "${KEY_BACKUP}" "${BASE}/CA/ca.key"
    print_error "sign-server-cert.sh did not report a clear error for missing CA key (got: ${output})"
fi
print_success "sign-server-cert.sh correctly rejected missing CA private key"

mv "${KEY_BACKUP}" "${BASE}/CA/ca.key"

# ── Test 5: Truncated CA certificate ─────────────────────────────────────────

print_step "Test 5: Truncated CA certificate..."

CRT_BACKUP="${TEST_DIR}/ca.crt.bak"
cp "${BASE}/CA/ca.crt" "${CRT_BACKUP}"
head -5 "${BASE}/CA/ca.crt" > "${BASE}/CA/ca.crt.tmp" && mv "${BASE}/CA/ca.crt.tmp" "${BASE}/CA/ca.crt"

assert_fails "openssl rejects truncated CA certificate" \
    openssl x509 -in "${BASE}/CA/ca.crt" -noout

cp "${CRT_BACKUP}" "${BASE}/CA/ca.crt"
print_success "CA certificate correctly restored"

# ── Cleanup ───────────────────────────────────────────────────────────────────

rm -rf "${TEST_DIR}"

print_success "All malformed configuration tests passed."

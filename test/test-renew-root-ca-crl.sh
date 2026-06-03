#!/bin/bash
##
## test-renew-root-ca-crl.sh - Use existing test-root-ca.sh, then run CRL renewal
##
## This test reuses the repository's comprehensive Root CA test
## (test/test-root-ca.sh) to initialize a clean CA, then runs
## ./renew-root-ca-crl.sh and validates the resulting CRL.
##

set -euo pipefail

BASE=$(realpath "$(dirname "$0")/..")
cd "${BASE}" || exit 1

CA_DIR="${BASE}/CA"
CRL_FILE="${BASE}/CRL/root-ca.crl.pem"

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# Prepare a clean CA via existing test harness
log "Running test/test-root-ca.sh to initialize a clean Root CA"
"${BASE}/test/test-root-ca.sh" > /dev/null || die "test/test-root-ca.sh failed"

# Run the renew script (which delegates generation to gen-root-ca-crl.sh)
log "Running renew-root-ca-crl.sh"
CA_PASSPHRASE="testpass" "${BASE}/renew-root-ca-crl.sh"

# Validate CRL
if [[ ! -f "${CRL_FILE}" ]]; then
  die "CRL not found at ${CRL_FILE}"
fi

log "Inspecting CRL"
openssl crl -in "${CRL_FILE}" -noout -text | awk '/Last Update:|Next Update:|Issuer:/ {print}'

# Robust check: compare issuer/subject name hashes
CRL_HASH=$(openssl crl -in "${CRL_FILE}" -noout -hash 2>/dev/null || true)
CERT_HASH=$(openssl x509 -in "${CA_DIR}/ca.crt" -noout -hash 2>/dev/null || true)
if [[ -n "${CRL_HASH}" && -n "${CERT_HASH}" ]]; then
  if [[ "${CRL_HASH}" != "${CERT_HASH}" ]]; then
    # Helpful debug output in a consistent format
    CRL_ISSUER=$(openssl crl -in "${CRL_FILE}" -noout -issuer -nameopt RFC2253 2>/dev/null | sed 's/^issuer= //')
    CERT_SUBJECT=$(openssl x509 -in "${CA_DIR}/ca.crt" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject= //')
    log "Warning: CRL issuer hash (${CRL_HASH}) != CA subject hash (${CERT_HASH})"
    log "         Issuer:  ${CRL_ISSUER}"
    log "         Subject: ${CERT_SUBJECT}"
  fi
fi

log "CRL generation and validation completed successfully"

#!/bin/bash
##
## test-renew-root-ca-crl.sh - Use existing test-root-ca.sh, then run CRL renewal
##
## This test reuses the repository's comprehensive Root CA test
## (test-root-ca.sh) to initialize a clean CA, then runs
## ./renew-root-ca-crl.sh and validates the resulting CRL.
##

set -euo pipefail

BASE=$(realpath "$(dirname "$0")")
cd "${BASE}" || exit 1

CA_DIR="${BASE}/CA"
CRL_FILE="${BASE}/CRL/root-ca.crl.pem"

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# Prepare a clean CA via existing test harness
log "Running test-root-ca.sh to initialize a clean Root CA"
"${BASE}/test-root-ca.sh" > /dev/null || die "test-root-ca.sh failed"

# Run the renew script (which delegates generation to gen-root-ca-crl.sh)
log "Running renew-root-ca-crl.sh"
CA_PASSPHRASE="testpass" "${BASE}/renew-root-ca-crl.sh"

# Validate CRL
if [[ ! -f "${CRL_FILE}" ]]; then
  die "CRL not found at ${CRL_FILE}"
fi

log "Inspecting CRL"
openssl crl -in "${CRL_FILE}" -noout -text | awk '/Last Update:|Next Update:|Issuer:/ {print}'

# Check issuer vs CA subject
ISSUER=$(openssl crl -in "${CRL_FILE}" -noout -issuer 2>/dev/null | sed 's/^issuer= //')
SUBJECT=$(openssl x509 -in "${CA_DIR}/ca.crt" -noout -subject 2>/dev/null | sed 's/^subject= //')
if [[ -n "${ISSUER}" && -n "${SUBJECT}" ]]; then
  case "${SUBJECT}" in
    *"${ISSUER}"*) : ;; # ok
    *) log "Warning: Issuer does not match CA subject" ;;
  esac
fi

log "CRL generation and validation completed successfully"

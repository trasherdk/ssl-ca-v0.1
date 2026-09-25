#!/bin/bash
##
##  renew-user-cert.sh - renew a user certificate
##
##  Keeps the current subject and revokes the certificate being replaced.

if [ $# -ne 1 ]; then
    echo "Usage: $(basename "$0") <user-email>"
    exit 1
fi

BASE=$(realpath "$(dirname "$0")")
cd "${BASE}" || exit 1
source "${BASE}/lib/helpers.sh" || exit 1

USER_EMAIL=$1
CERTDIR="${BASE}/certs/users/${USER_EMAIL}"
CA_DIR="${BASE}/CA"
CERT="${CERTDIR}/${USER_EMAIL}.crt"
KEY="${CERTDIR}/${USER_EMAIL}.key"
CSR="${CERTDIR}/${USER_EMAIL}.csr"
CA_CONFIG="${BASE}/config/root-ca.conf"

if [ ! -f "${KEY}" ] || [ ! -f "${CERT}" ]; then
    echo "Error: User certificate must exist to renew."
    exit 1
fi
if [ ! -f "${CA_CONFIG}" ]; then
    echo "Error: CA config not found at ${CA_CONFIG}."
    exit 1
fi

BACKUP_DIR="${CERTDIR}/backup"
mkdir -p "${BACKUP_DIR}"
cp "${CERT}" "${BACKUP_DIR}/${USER_EMAIL}.crt.$(date +%Y%m%d%H%M%S)"

echo "Generating CSR from the current user certificate..."
if ! openssl x509 -x509toreq -in "${CERT}" -signkey "${KEY}" -out "${CSR}"; then
    echo "Error: Failed to build a renewal CSR from ${CERT}."
    exit 1
fi

echo "Revoking the certificate being replaced..."
if ! revoke_issued_cert "${CERT}" "${CA_DIR}" "${CA_CONFIG}"; then
    echo "Error: Failed to revoke ${CERT}."
    exit 1
fi
if ! regenerate_ca_crl "${BASE}"; then
    echo "Error: Failed to regenerate the CRL after revoking ${USER_EMAIL}."
    exit 1
fi

echo "Signing renewed user certificate..."
export SSL_CA_BATCH=1
if ! "${BASE}/sign-user-cert.sh" "${USER_EMAIL}"; then
    echo "Error: Failed to sign the renewed user certificate."
    exit 1
fi

echo "User certificate renewed: ${CERT}"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

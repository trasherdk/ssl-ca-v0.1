#!/bin/bash
##
##  renew-server-cert.sh - renew a server certificate
##
##  Keeps the current subject and DNS names, and revokes the certificate
##  being replaced.

if [ $# -ne 1 ]; then
    echo "Usage: $(basename "$0") <server-name>"
    exit 1
fi

BASE=$(realpath "$(dirname "$0")")
cd "${BASE}" || exit 1
source "${BASE}/lib/helpers.sh" || exit 1

SERVER_NAME=$1
CERTDIR="${BASE}/certs/${SERVER_NAME}"
CA_DIR="${BASE}/CA"
CERT="${CERTDIR}/${SERVER_NAME}.crt"
KEY="${CERTDIR}/${SERVER_NAME}.key"
CSR="${CERTDIR}/${SERVER_NAME}.csr"
CA_CONFIG="${BASE}/config/root-ca.conf"

if [ ! -f "${KEY}" ] || [ ! -f "${CERT}" ]; then
    echo "Error: Server certificate must exist to renew."
    exit 1
fi
if [ ! -f "${CA_CONFIG}" ]; then
    echo "Error: CA config not found at ${CA_CONFIG}."
    exit 1
fi

BACKUP_DIR="${CERTDIR}/backup"
mkdir -p "${BACKUP_DIR}"
cp "${CERT}" "${BACKUP_DIR}/${SERVER_NAME}.crt.$(date +%Y%m%d%H%M%S)"

echo "Generating CSR from the current server certificate..."
if ! openssl x509 -x509toreq -in "${CERT}" -signkey "${KEY}" -out "${CSR}"; then
    echo "Error: Failed to build a renewal CSR from ${CERT}."
    exit 1
fi

EXTRA_DNS=()
while IFS= read -r name; do
    if [ -n "${name}" ] && [ "${name}" != "${SERVER_NAME}" ]; then
        EXTRA_DNS+=("${name}")
    fi
done < <(openssl x509 -in "${CERT}" -noout -ext subjectAltName 2>/dev/null \
    | grep -o 'DNS:[^, ]*' | cut -d: -f2-)

echo "Revoking the certificate being replaced..."
if ! revoke_issued_cert "${CERT}" "${CA_DIR}" "${CA_CONFIG}"; then
    echo "Error: Failed to revoke ${CERT}."
    exit 1
fi
if ! regenerate_ca_crl "${BASE}"; then
    echo "Error: Failed to regenerate the CRL after revoking ${CERT}."
    exit 1
fi

echo "Signing renewed server certificate..."
export SSL_CA_BATCH=1
if ! "${BASE}/sign-server-cert.sh" "${SERVER_NAME}" "${EXTRA_DNS[@]}"; then
    echo "Error: Failed to sign the renewed server certificate."
    exit 1
fi

echo "Server certificate renewed: ${CERT}"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

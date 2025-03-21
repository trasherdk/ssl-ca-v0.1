#!/bin/bash
##
##  renew-server-cert.sh - renew a server certificate
##

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) <server-name>"
    exit 1
fi

BASE=$(realpath $(dirname $0))
SERVER_NAME=$1
CERTDIR="${BASE}/certs/${SERVER_NAME}"
CA_DIR="${BASE}/CA"

# Ensure server certificate exists
if [ ! -f "${CERTDIR}/${SERVER_NAME}.key" ] || [ ! -f "${CERTDIR}/${SERVER_NAME}.crt" ]; then
    echo "Error: Server certificate must exist to renew."
    exit 1
fi

# Backup the existing certificate
BACKUP_DIR="${CERTDIR}/backup"
mkdir -p "${BACKUP_DIR}"
cp "${CERTDIR}/${SERVER_NAME}.crt" "${BACKUP_DIR}/${SERVER_NAME}.crt.$(date +%Y%m%d%H%M%S)"

# Renew the server certificate
CONFIG="${CERTDIR}/${SERVER_NAME}-server-cert.conf"
CSR="${CERTDIR}/${SERVER_NAME}.csr"
NEW_CERT="${CERTDIR}/${SERVER_NAME}.crt"

echo "Generating CSR for server certificate renewal..."
openssl req -new -key "${CERTDIR}/${SERVER_NAME}.key" -out "${CSR}" -config "${CONFIG}"

echo "Signing renewed server certificate with root CA..."
openssl ca -config "${BASE}/config/root-ca.conf" -extensions server_cert -days 3650 \
    -in "${CSR}" -out "${NEW_CERT}" -keyfile "${CA_DIR}/ca.key" -cert "${CA_DIR}/ca.crt"

# Cleanup
rm -f "${CSR}"

echo "Server certificate renewed: ${NEW_CERT}"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

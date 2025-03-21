#!/bin/bash
##
##  renew-sub-ca.sh - renew a sub-CA certificate
##

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) <sub-ca-name>"
    exit 1
fi

BASE=$(realpath $(dirname $0))
SUB_CA_NAME=$1
SUB_CA_DIR="${BASE}/sub-CAs/${SUB_CA_NAME}"
SUB_CA_CA_DIR="${SUB_CA_DIR}/CA"
ROOT_CA_DIR="${BASE}/CA"

# Ensure sub-CA exists
if [ ! -f "${SUB_CA_CA_DIR}/${SUB_CA_NAME}.key" ] || [ ! -f "${SUB_CA_CA_DIR}/${SUB_CA_NAME}.crt" ]; then
    echo "Error: Sub-CA must exist to renew."
    exit 1
fi

# Backup the existing certificate
BACKUP_DIR="${SUB_CA_CA_DIR}/backup"
mkdir -p "${BACKUP_DIR}"
cp "${SUB_CA_CA_DIR}/${SUB_CA_NAME}.crt" "${BACKUP_DIR}/${SUB_CA_NAME}.crt.$(date +%Y%m%d%H%M%S)"

# Renew the sub-CA certificate
CONFIG="${SUB_CA_DIR}/config/${SUB_CA_NAME}-sub-ca.conf"
NEW_CERT="${SUB_CA_CA_DIR}/${SUB_CA_NAME}.crt"
CSR="${SUB_CA_CA_DIR}/${SUB_CA_NAME}.csr"

echo "Generating CSR for sub-CA renewal..."
openssl req -new -key "${SUB_CA_CA_DIR}/${SUB_CA_NAME}.key" -out "${CSR}" -config "${CONFIG}"

echo "Signing renewed sub-CA certificate with root CA..."
openssl ca -config "${BASE}/config/root-ca.conf" -extensions v3_sub_ca -days 3650 \
    -in "${CSR}" -out "${NEW_CERT}" -keyfile "${ROOT_CA_DIR}/ca.key" -cert "${ROOT_CA_DIR}/ca.crt"

# Cleanup
rm -f "${CSR}"

echo "Sub-CA certificate renewed: ${NEW_CERT}"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

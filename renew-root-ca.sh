#!/bin/bash
##
##  renew-root-ca.sh - renew the root CA certificate
##

BASE=$(realpath $(dirname $0))
ROOT_CA_DIR="${BASE}/CA"

# Ensure root CA exists
if [ ! -f "${ROOT_CA_DIR}/ca.key" ] || [ ! -f "${ROOT_CA_DIR}/ca.crt" ]; then
    echo "Error: Root CA must exist to renew."
    exit 1
fi

# Backup the existing certificate
BACKUP_DIR="${ROOT_CA_DIR}/backup"
mkdir -p "${BACKUP_DIR}"
cp "${ROOT_CA_DIR}/ca.crt" "${BACKUP_DIR}/ca.crt.$(date +%Y%m%d%H%M%S)"

# Renew the root CA certificate
CONFIG="${BASE}/config/root-ca.conf"
NEW_CERT="${ROOT_CA_DIR}/ca.crt"

echo "Renewing root CA certificate..."
openssl req -new -x509 -days 3650 -config "${CONFIG}" -key "${ROOT_CA_DIR}/ca.key" -out "${NEW_CERT}"

echo "Root CA certificate renewed: ${NEW_CERT}"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

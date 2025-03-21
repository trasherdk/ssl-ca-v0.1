#!/bin/bash
##
##  renew-user-cert.sh - renew a user certificate
##

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) <user-email>"
    exit 1
fi

BASE=$(realpath $(dirname $0))
USER_EMAIL=$1
CERTDIR="${BASE}/certs/users/${USER_EMAIL}"
CA_DIR="${BASE}/CA"

# Ensure user certificate exists
if [ ! -f "${CERTDIR}/${USER_EMAIL}.key" ] || [ ! -f "${CERTDIR}/${USER_EMAIL}.crt" ]; then
    echo "Error: User certificate must exist to renew."
    exit 1
fi

# Backup the existing certificate
BACKUP_DIR="${CERTDIR}/backup"
mkdir -p "${BACKUP_DIR}"
cp "${CERTDIR}/${USER_EMAIL}.crt" "${BACKUP_DIR}/${USER_EMAIL}.crt.$(date +%Y%m%d%H%M%S)"

# Renew the user certificate
CONFIG="${CERTDIR}/${USER_EMAIL}-user-cert.conf"
CSR="${CERTDIR}/${USER_EMAIL}.csr"
NEW_CERT="${CERTDIR}/${USER_EMAIL}.crt"

echo "Generating CSR for user certificate renewal..."
openssl req -new -key "${CERTDIR}/${USER_EMAIL}.key" -out "${CSR}" -config "${CONFIG}"

echo "Signing renewed user certificate with root CA..."
openssl ca -config "${BASE}/config/root-ca.conf" -extensions user_cert -days 3650 \
    -in "${CSR}" -out "${NEW_CERT}" -keyfile "${CA_DIR}/ca.key" -cert "${CA_DIR}/ca.crt"

# Cleanup
rm -f "${CSR}"

echo "User certificate renewed: ${NEW_CERT}"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

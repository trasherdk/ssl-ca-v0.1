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
CONFIG="${CERTDIR}/config/user-cert.conf"
CSR="${CERTDIR}/${USER_EMAIL}.csr"

echo "Generating CSR for user certificate renewal..."
openssl req -new -batch -key "${CERTDIR}/${USER_EMAIL}.key" -out "${CSR}" -config "${CONFIG}"

echo "Signing renewed user certificate with root CA..."
"${BASE}/sign-user-cert.sh" "${USER_EMAIL}"

echo "User certificate renewed: ${CERTDIR}/${USER_EMAIL}.crt"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

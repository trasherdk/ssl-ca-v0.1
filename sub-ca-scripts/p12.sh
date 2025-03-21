#!/bin/bash
##
##  p12.sh - package a user certificate into a PKCS#12 file
##

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) <user-email>"
    exit 1
fi

BASE=$(realpath $(dirname $0)/..)
SUB_CA_DIR="${BASE}/sub-CAs/<sub-ca-name>"
CA_DIR="${SUB_CA_DIR}/CA"
# ...existing code...

USER=$1
CERTDIR="${SUB_CA_DIR}/certs/users/${USER}"

# Ensure required files exist
if [ ! -f "${CERTDIR}/${USER}.key" ] || [ ! -f "${CERTDIR}/${USER}.crt" ] || [ ! -f "${CA_DIR}/${SUB_CA_NAME}.crt" ]; then
    echo "Error: Missing required files for ${USER}."
    exit 1
fi

# Extract names for the PKCS#12 file
username="$(openssl x509 -noout -in "${CERTDIR}/${USER}.crt" -subject | sed -n 's/.*CN=//p' | cut -d'/' -f1)"
caname="$(openssl x509 -noout -in "${CA_DIR}/${SUB_CA_NAME}.crt" -subject | sed -n 's/.*CN=//p' | cut -d'/' -f1)"

# Package into PKCS#12
openssl pkcs12 -export \
    -in "${CERTDIR}/${USER}.crt" \
    -inkey "${CERTDIR}/${USER}.key" \
    -certfile "${CA_DIR}/${SUB_CA_NAME}.crt" \
    -name "${username}" \
    -caname "${caname}" \
    -out "${CERTDIR}/${USER}.p12"

echo "PKCS#12 file created: ${CERTDIR}/${USER}.p12"

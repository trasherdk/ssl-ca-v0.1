#!/bin/bash
##
##  new-user-cert.sh - create a user certificate under a sub-CA
##

if [ $# -lt 1 ]; then
    echo "Usage: $(basename $0) <email|username> [email]"
    exit 1
fi

BASE=$(realpath $(dirname $0)/..)
SUB_CA_DIR="${BASE}/sub-CAs/<sub-ca-name>"
CA_DIR="${SUB_CA_DIR}/CA"

# Determine if $1 is an email (contains '@')
if [[ "$1" == *@* ]]; then
    EMAIL=$1
    USERNAME=$1
else
    USERNAME=$1
    EMAIL=$2
fi

if [ -z "$EMAIL" ]; then
    echo "Error: Email is required if username is provided."
    exit 1
fi

CERTDIR="${SUB_CA_DIR}/certs/users/${USERNAME}"

# Ensure sub-CA exists
if [ ! -f "${CA_DIR}/${SUB_CA_NAME}.key" ] || [ ! -f "${CA_DIR}/${SUB_CA_NAME}.crt" ]; then
    echo "Error: Sub-CA must be created first."
    exit 1
fi

# Create user certificate directory
if [ ! -d "${CERTDIR}" ]; then
    mkdir -p "${CERTDIR}"
    chmod g-rwx,o-rwx "${CERTDIR}"
fi

# Generate private key
if [ -f "${CERTDIR}/${USERNAME}.key" ]; then
    echo "Error: A certificate for ${USERNAME} already exists."
    exit 1
fi

openssl genrsa -out "${CERTDIR}/${USERNAME}.key" 4096

# Generate CSR
CONFIG="${CERTDIR}/${USERNAME}-user-cert.conf"
cat >"${CONFIG}" <<EOT
[ req ]
default_bits            = 4096
default_keyfile         = user.key
distinguished_name      = req_distinguished_name
string_mask             = nombstr
req_extensions          = v3_req
[ req_distinguished_name ]
commonName              = Common Name (eg, John Doe)
commonName_default      = ${USERNAME}
emailAddress            = Email Address
emailAddress_default    = ${EMAIL}
[ v3_req ]
nsCertType              = client,email
basicConstraints        = critical,CA:false
subjectAltName          = email:${EMAIL}
EOT

openssl req -new -config "${CONFIG}" -key "${CERTDIR}/${USERNAME}.key" -out "${CERTDIR}/${USERNAME}.csr"

echo "CSR generated for ${USERNAME} (${EMAIL}). You may now sign it using the sub-CA."

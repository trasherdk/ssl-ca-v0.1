#!/bin/bash
##
##  sign-user-cert.sh - sign a user certificate using a sub-CA
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

# Ensure sub-CA exists
if [ ! -f "${CA_DIR}/${SUB_CA_NAME}.key" ] || [ ! -f "${CA_DIR}/${SUB_CA_NAME}.crt" ]; then
    echo "Error: Sub-CA must be created first."
    exit 1
fi

# Ensure CSR exists
if [ ! -f "${CERTDIR}/${USER}.csr" ]; then
    echo "Error: CSR for ${USER} not found. Generate it first."
    exit 1
fi

# Generate signing configuration
CONFIG="${CERTDIR}/${USER}-user-sign.conf"
cat >"${CONFIG}" <<EOT
[ ca ]
default_ca              = default_CA
[ default_CA ]
dir                     = ${CA_DIR}
certs                   = \$dir/ca.db.certs
new_certs_dir           = \$dir/ca.db.certs
database                = \$dir/ca.db.index
serial                  = \$dir/ca.db.serial
RANDFILE                = \$dir/random-bits
certificate             = \$dir/${SUB_CA_NAME}.crt
private_key             = \$dir/${SUB_CA_NAME}.key
default_days            = 3650
default_md              = sha256
preserve                = no
x509_extensions         = user_cert
policy                  = policy_anything
[ user_cert ]
basicConstraints        = critical,CA:false
keyUsage                = digitalSignature, keyEncipherment
extendedKeyUsage        = clientAuth,emailProtection
EOT

# Sign the certificate
openssl ca -config "${CONFIG}" -out "${CERTDIR}/${USER}.crt" -infiles "${CERTDIR}/${USER}.csr"

# Cleanup
rm -f "${CONFIG}"

echo "Certificate signed: ${CERTDIR}/${USER}.crt"

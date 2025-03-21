#!/bin/bash
##
##  sign-server-cert.sh - sign a server certificate using a sub-CA
##

if [ $# -lt 1 ]; then
    echo "Usage: $(basename $0) <www.domain.com> [alt1.domain.com alt2.domain.com]"
    exit 1
fi

BASE=$(realpath $(dirname $0)/..)
SUB_CA_DIR="${BASE}/sub-CAs/<sub-ca-name>"
CA_DIR="${SUB_CA_DIR}/CA"

# Ensure sub-CA exists
if [ ! -f "${CA_DIR}/${SUB_CA_NAME}.key" ] || [ ! -f "${CA_DIR}/${SUB_CA_NAME}.crt" ]; then
    echo "Error: Sub-CA must be created first."
    exit 1
fi

CERT=$1
shift
CERTDIR="${SUB_CA_DIR}/certs/${CERT}"

# Ensure CSR exists
if [ ! -f "${CERTDIR}/${CERT}.csr" ]; then
    echo "Error: CSR for ${CERT} not found. Generate it first."
    exit 1
fi

# Generate signing configuration
CONFIG="${CERTDIR}/${CERT}-server-sign.conf"
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
x509_extensions         = server_cert
policy                  = policy_anything
[ policy_anything ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
[ server_cert ]
basicConstraints        = critical,CA:false
keyUsage                = digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth
EOT

# Sign the certificate
openssl ca -config "${CONFIG}" -out "${CERTDIR}/${CERT}.crt" -infiles "${CERTDIR}/${CERT}.csr"

# Cleanup
rm -f "${CONFIG}"

echo "Certificate signed: ${CERTDIR}/${CERT}.crt"

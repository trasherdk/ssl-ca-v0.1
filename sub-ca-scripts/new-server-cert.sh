#!/bin/bash
##
##  new-server-cert.sh - create a server certificate under a sub-CA
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

# Create certificate directory if it doesn't exist
if [ ! -d "${CERTDIR}" ]; then
    mkdir -p "${CERTDIR}"
    chmod g-rwx,o-rwx "${CERTDIR}"
fi

# Generate private key for the server certificate
if [ -f "${CERTDIR}/${CERT}.key" ]; then
    echo "Error: A certificate for ${CERT} already exists."
    exit 1
fi

openssl genrsa -out "${CERTDIR}/${CERT}.key" 4096

# Generate the CSR
CONFIG="${CERTDIR}/${CERT}-server-cert.conf"
cat >"${CONFIG}" <<EOT
[ req ]
default_bits            = 4096
default_keyfile         = server.key
distinguished_name      = req_distinguished_name
string_mask             = nombstr
req_extensions          = v3_req
[ req_distinguished_name ]
countryName             = Country Name (2 letter code)
countryName_default     = DK
stateOrProvinceName     = State or Province Name (full name)
stateOrProvinceName_default = Denmark
localityName            = Locality Name (eg, city)
localityName_default    = Copenhagen
organizationName        = Organization Name (eg, company)
organizationName_default = Trader Internet
organizationalUnitName  = Organizational Unit Name (eg, section)
organizationalUnitName_default = Secure Server
commonName              = Common Name (eg, www.domain.com)
commonName_default      = ${CERT}
emailAddress            = Email Address
emailAddress_default    = hostmaster@fumlersoft.dk
[ v3_req ]
nsCertType              = server
basicConstraints        = critical,CA:false
EOT

openssl req -new -sha256 -config "${CONFIG}" -key "${CERTDIR}/${CERT}.key" -out "${CERTDIR}/${CERT}.csr"

echo "CSR generated for ${CERT}. You may now sign it using the sub-CA."

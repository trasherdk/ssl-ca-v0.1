#!/bin/bash
##
##  new-sub-ca.sh - create a sub-CA certificate signed by the root CA
##

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $(basename $0) <sub-ca-name> [no-sub-ca]"
    echo "  <sub-ca-name>: Name of the sub-CA"
    echo "  [no-sub-ca]: Optional. If set, this CA can only issue user/host certificates."
    exit 1
fi

BASE=$(realpath $(dirname $0))
cd "${BASE}"

SUB_CA_NAME=$1
NO_SUB_CA=${2:-no} # Default to allowing sub-CAs unless "no-sub-ca" is specified
SUB_CA_DIR="${BASE}/sub-CAs/${SUB_CA_NAME}"
SUB_CA_CA_DIR="${SUB_CA_DIR}/CA"
ROOT_CA_DIR="${BASE}/CA"

# Ensure root CA exists
if [ ! -f "${ROOT_CA_DIR}/ca.key" ] || [ ! -f "${ROOT_CA_DIR}/ca.crt" ]; then
    echo "Error: Root CA must be created first using new-root-ca.sh."
    exit 1
fi

# Create sub-CA directory structure
if [ ! -d "${SUB_CA_CA_DIR}" ]; then
    mkdir -p "${SUB_CA_CA_DIR}/ca.db.certs"
    echo "01" > "${SUB_CA_CA_DIR}/ca.db.serial"
    touch "${SUB_CA_CA_DIR}/ca.db.index"
    mkdir -p "${SUB_CA_DIR}/certs"
    mkdir -p "${SUB_CA_DIR}/crl"
    chmod -R g-rwx,o-rwx "${SUB_CA_DIR}"
fi

# Generate sub-CA private key
SUB_CA_KEY="${SUB_CA_CA_DIR}/${SUB_CA_NAME}.key"
if [ -f "${SUB_CA_KEY}" ]; then
    echo "Error: Sub-CA key already exists for ${SUB_CA_NAME}."
    exit 1
fi

echo "Generating private key for sub-CA: ${SUB_CA_NAME}..."
openssl genrsa -out "${SUB_CA_KEY}" 4096

# Determine which extension to use based on whether sub-CAs are allowed
if [ "${NO_SUB_CA}" = "no-sub-ca" ]; then
    SUB_CA_EXTENSION="v3_restricted_sub_ca"
    BASIC_CONSTRAINTS="critical,CA:false"
else
    SUB_CA_EXTENSION="v3_sub_ca"
    BASIC_CONSTRAINTS="critical,CA:true"
fi

# Generate sub-CA CSR
SUB_CA_CSR="${SUB_CA_CA_DIR}/${SUB_CA_NAME}.csr"
SUB_CA_CONFIG_DIR="${SUB_CA_DIR}/config"
SUB_CA_CONFIG="${SUB_CA_CONFIG_DIR}/${SUB_CA_NAME}-sub-ca.conf"

# Create config directory
mkdir -p "${SUB_CA_CONFIG_DIR}"
chmod 700 "${SUB_CA_CONFIG_DIR}"

# Create sub-CA config
cat >"${SUB_CA_CONFIG}" <<EOT
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = ${SUB_CA_CA_DIR}
certs = \$dir/ca.db.certs
database = \$dir/ca.db.index
new_certs_dir = \$dir/ca.db.certs
certificate = \$dir/${SUB_CA_NAME}.crt
serial = \$dir/ca.db.serial
private_key = \$dir/${SUB_CA_NAME}.key
RANDOM = /dev/urandom
default_days = 3650
default_md = sha256
preserve = no
policy = policy_match
default_bits = 4096

[ policy_match ]
countryName = match
stateOrProvinceName = match
localityName = match
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ req ]
default_bits            = 4096
default_keyfile         = sub-ca.key
distinguished_name      = req_distinguished_name
x509_extensions         = v3_sub_ca
string_mask             = nombstr
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
organizationalUnitName_default = ${SUB_CA_NAME} Sub-CA
commonName              = Common Name (eg, www.domain.com)
commonName_default      = ${SUB_CA_NAME}
emailAddress            = Email Address
emailAddress_default    = hostmaster@fumlersoft.dk
[ v3_sub_ca ]
basicConstraints        = critical,CA:true
keyUsage                = critical, keyCertSign, cRLSign
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer

[ v3_restricted_sub_ca ]
basicConstraints        = critical,CA:false
keyUsage                = critical,digitalSignature,keyEncipherment
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
EOT

echo "Generating CSR for sub-CA: ${SUB_CA_NAME}..."
openssl req -new -key "${SUB_CA_KEY}" -out "${SUB_CA_CSR}" -config "${SUB_CA_CONFIG}"

# Sign the sub-CA certificate with the root CA
SUB_CA_CERT="${SUB_CA_CA_DIR}/${SUB_CA_NAME}.crt"
ROOT_CA_CONFIG="${BASE}/config/root-ca.conf"

echo "Signing sub-CA certificate with root CA..."
openssl ca -config "${ROOT_CA_CONFIG}" -extensions "${SUB_CA_EXTENSION}" -days 3650 \
    -in "${SUB_CA_CSR}" -out "${SUB_CA_CERT}" -keyfile "${ROOT_CA_DIR}/ca.key" \
    -cert "${ROOT_CA_DIR}/ca.crt"

# Cleanup
rm -f "${SUB_CA_CSR}" "${SUB_CA_CONFIG}"

echo "Sub-CA certificate created: ${SUB_CA_CERT}"
echo "Sub-CA directory structure initialized at: ${SUB_CA_DIR}"

# Copy scripts to sub-CA root
echo "Copying scripts to sub-CA directory..."
cp "${BASE}/sub-ca-scripts/"* "${SUB_CA_DIR}/"
cp "${BASE}/new-sub-ca.sh" "${SUB_CA_DIR}/"
chmod +x "${SUB_CA_DIR}/"*.sh

echo "Sub-CA is now ready to operate independently."

#!/bin/bash
##
##  new-sub-ca.sh - create a sub-CA certificate signed by the root CA
##

BASE=$(realpath $(dirname $0))
cd "${BASE}"

source ./lib/helpers.sh || exit 1

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    print_soft_error "$(basename $0) <sub-ca-name> [no-sub-ca]"
    print_soft_error "  <sub-ca-name>: Name of the sub-CA"
    print_error "  [no-sub-ca]: Optional. If set, this CA can only issue user/host certificates."
fi

# Check if we're a restricted CA by examining our own certificate
if [ -f "CA/ca.crt" ]; then
    cert_text=$(openssl x509 -in "CA/ca.crt" -text -noout)
    if echo "$cert_text" | grep -q "pathlen:0"; then
        print_error "This is a restricted CA and cannot create new sub-CAs."
    fi
fi

SUB_CA_NAME=$1
NO_SUB_CA=${2:-no} # Default to allowing sub-CAs unless "no-sub-ca" is specified
# Define directories
ROOT_CA_DIR="${BASE}/CA"
SUB_CA_DIR="${BASE}/sub-CAs/${SUB_CA_NAME}"  # Operational directory
SUB_CA_CA_DIR="${SUB_CA_DIR}/CA"
SUB_CA_REGISTRY="${BASE}/certs/sub-CAs/${SUB_CA_NAME}"  # Registry directory

# Ensure root CA exists
if [ ! -f "${ROOT_CA_DIR}/ca.key" ] || [ ! -f "${ROOT_CA_DIR}/ca.crt" ]; then
    print_error "Root CA must be created first using new-root-ca.sh."
fi

print_step "Create directory structure"
print_step "1. Operational directory for active sub-CA"
if [ ! -d "${SUB_CA_CA_DIR}" ]; then
    mkdir -p "${SUB_CA_CA_DIR}/ca.db.certs"
    echo "01" > "${SUB_CA_CA_DIR}/ca.db.serial"
    touch "${SUB_CA_CA_DIR}/ca.db.index"
    mkdir -p "${SUB_CA_DIR}/certs"
    mkdir -p "${SUB_CA_DIR}/crl"
    mkdir -p "${SUB_CA_DIR}/lib"
    mkdir -p "${SUB_CA_DIR}/test"
    chmod -R g-rwx,o-rwx "${SUB_CA_DIR}"
fi

print_step "2. Registry directory for tracking sub-CA certificates"
if [ ! -d "${SUB_CA_REGISTRY}" ]; then
    mkdir -p "${SUB_CA_REGISTRY}"
    chmod -R g-rwx,o-rwx "${SUB_CA_REGISTRY}"
fi

print_step "3. Generate sub-CA private key"
SUB_CA_KEY="${SUB_CA_CA_DIR}/ca.key"
if [ -f "${SUB_CA_KEY}" ]; then
    print_error "Sub-CA key already exists for ${SUB_CA_NAME}."
fi

print_step "Generating private key for sub-CA: ${SUB_CA_NAME}..."
openssl genrsa -out "${SUB_CA_KEY}" 4096

print_step "4. Ensure the correct extension is used for Sub-CAs"
if [ "${NO_SUB_CA}" = "no-sub-ca" ]; then
    SUB_CA_EXTENSION="v3_restricted_sub_ca"
else
    SUB_CA_EXTENSION="v3_ca"
fi

print_step "5. Generate sub-CA CSR"
SUB_CA_CSR="${SUB_CA_CA_DIR}/${SUB_CA_NAME}.csr"
SUB_CA_CONFIG_DIR="${SUB_CA_DIR}/config"
SUB_CA_CONFIG="${SUB_CA_CONFIG_DIR}/${SUB_CA_NAME}-sub-ca.conf"

print_step "6. Create config directory"
mkdir -p "${SUB_CA_CONFIG_DIR}"
chmod 700 "${SUB_CA_CONFIG_DIR}"

print_step "7. Create sub-CA config"
cat >"${SUB_CA_CONFIG}" <<EOT
[ ca ]
default_ca = CA_default

[ CA_default ]
dir                     = ./CA
certs                   = \$dir/ca.db.certs
database                = \$dir/ca.db.index
new_certs_dir           = \$dir/ca.db.certs
certificate             = \$dir/ca.crt
serial                  = \$dir/ca.db.serial
private_key             = \$dir/ca.key
RANDOM                  = /dev/urandom
default_days            = 3650
default_md              = sha256
preserve                = no
policy                  = policy_match
default_bits            = 4096

[ policy_match ]
countryName             = match
stateOrProvinceName     = match
localityName            = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

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
keyUsage                = critical,keyCertSign,cRLSign
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer

[ v3_restricted_sub_ca ]
basicConstraints        = critical,CA:true,pathlen:0
keyUsage                = critical,keyCertSign,cRLSign
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
EOT

print_step "8. Generating CSR for sub-CA: ${SUB_CA_NAME}..."
openssl req -new -key "${SUB_CA_KEY}" -out "${SUB_CA_CSR}" -config "${SUB_CA_CONFIG}"

# Sign the sub-CA certificate with the root CA
SUB_CA_CERT="${SUB_CA_CA_DIR}/ca.crt"
ROOT_CA_CONFIG="${BASE}/config/root-ca.conf"

print_step "9. Signing sub-CA certificate with root CA..."
openssl ca -config "${ROOT_CA_CONFIG}" -extensions "${SUB_CA_EXTENSION}" -days 3650 \
    -in "${SUB_CA_CSR}" -out "${SUB_CA_CERT}" -keyfile "${ROOT_CA_DIR}/ca.key" \
    -cert "${ROOT_CA_DIR}/ca.crt"

print_step "10. Append the current CA's certificate to the new Sub-CA's certificate"
cat "${BASE}/CA/ca.crt" >> "$SUB_CA_CERT"

# Validate the Sub-CA certificate after signing and appending the root CA's certificate
# Update the openssl verify command to use the second-level Sub-CA's CA/ca.crt file
print_step "11. Validate the Sub-CA certificate after signing and appending the root CA's certificate"
openssl verify -CAfile "$SUB_CA_CERT" "$SUB_CA_CERT" > "${SUB_CA_CA_DIR}/ca-verify.log" 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Sub-CA certificate validation failed. Check ${SUB_CA_CA_DIR}/ca-verify.log for details."
    exit 1
fi

print_step "12. Store a copy in the registry"
# Create registry directory for this sub-CA if it doesn't exist
mkdir -p "${SUB_CA_REGISTRY}/${SUB_CA_NAME}"
chmod 700 "${SUB_CA_REGISTRY}/${SUB_CA_NAME}"

# Store sub-CA certificate in registry
cp "$SUB_CA_CERT" "${SUB_CA_REGISTRY}/${SUB_CA_NAME}/ca.crt"

# Cleanup
rm -f "${SUB_CA_CSR}" "${SUB_CA_CONFIG}"

print_step "13. Copy scripts to sub-CA directory"
scripts=(
    "new-server-cert.sh" 
    "new-user-cert.sh" 
    "new-sub-ca.sh" 
    "check-expiry.sh" 
    "sign-server-cert.sh" 
    "sign-user-cert.sh" 
    "server-p12.sh"
    "user-p12.sh"
    "revoke-cert.sh"
    "revoke-server-cert.sh"
    "revoke-user-cert.sh"
    "test-sub-ca.sh"
    "test-server-cert.sh"
    "test-user-cert.sh"
    )

for script in "${scripts[@]}"; do
    if [ -f "${BASE}/${script}" ]; then
        cp -p "${BASE}/${script}" "${SUB_CA_DIR}/"
    fi
done

print_step "14. Copy helper scripts to lib directory"
cp -p "${BASE}/lib/helpers.sh" "${SUB_CA_DIR}/lib/"

print_step "15. Copy test scripts to test directory"
cp -p "${BASE}/test/test-sub-ca-autonomy.sh" "${SUB_CA_DIR}/test/"

# Copy the root-ca.conf file to the Sub-CA's config directory
cp "${BASE}/config/root-ca.conf" "${SUB_CA_DIR}/config/"

# Copy the test-sub-ca.sh script to the Sub-CA directory
cp "${BASE}/test-sub-ca.sh" "${SUB_CA_DIR}/"

print_success "16. Sub-CA is now ready to operate independently."

#!/bin/bash
##
##  new-server-cert.sh - create the server cert
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved.
##

if [ $# -lt 1 ]; then
    echo "Usage: $(basename $0) <www.domain.com> [alt1.domain.com alt2.domain.com] "
    exit 1
fi

BASE=$(realpath $(dirname $0))
cd "${BASE}"

source "${BASE}/lib/helpers.sh" || exit 1

KEYBITS=4096
HASHALGO="sha256"
VALID_DAYS=3650
RANDOM_SRC=/dev/urandom

# Create the key. This should be done once per cert.
CERT=$1
shift

CA="${BASE}/CA"
if [ ! -d ${CA} ]; then
    print_error "Missing CA directory..."
fi

# Check for root CA key
if [ ! -f "${CA}/ca.key" -o ! -f "${CA}/ca.crt" ]; then
    print_error "You must have root CA certificate generated first."
fi

CERTDIR="${BASE}/certs/${CERT}"
if [ ! -d "${CERTDIR}" ]; then
    mkdir -p "${CERTDIR}"
    chmod g-rwx,o-rwx "${CERTDIR}"
fi

if [ -f "${CERTDIR}/${CERT}.key" ]; then
    print_error "A certificate for ${CERT} exist. Revoke and remove existing."
fi

print_step "No ${CERT}.key round. Generating one"
openssl genrsa -out "${CERTDIR}/${CERT}.key" ${KEYBITS}

# Fill the necessary certificate data

CONFIG="${CERTDIR}/config/server-cert.conf"

if [ ! -d $(dirname ${CONFIG}) ];then
    mkdir $(dirname ${CONFIG})
fi

cat >${CONFIG} <<EOT
[ req ]
default_bits                    = ${KEYBITS}
default_keyfile                 = server.key
distinguished_name              = req_distinguished_name
string_mask                     = nombstr
req_extensions                  = v3_req

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_default             = DK
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = Denmark
localityName                    = Locality Name (eg, city)
localityName_default            = Copenhagen
0.organizationName              = Organization Name (eg, company)
0.organizationName_default      = Trader Internet
organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_default  = Secure Server
commonName                      = Common Name (eg, www.domain.com)
commonName_default              = ${CERT}
commonName_max                  = 64
emailAddress                    = Email Address
emailAddress_default            = hostmaster@fumlersoft.dk
emailAddress_max                = 40

[ v3_req ]
nsCertType                      = server
basicConstraints                = critical,CA:false
subjectAltName                  = @alt_names
[ alt_names ]
DNS.1                           = ${CERT}
EOT

CNT=2
ALT_NAMES=""
TMP_NAMES="${CERT}"

while [ $# -gt 0 ]
do
    ALT_NAMES="${ALT_NAMES}DNS.${CNT}                           = ${1}\n"
    TMP_NAMES="${TMP_NAMES} ${1}"
    ((CNT++))
    shift
done
echo -e "${ALT_NAMES}" >> ${CONFIG}

print_step "Fill in certificate data"
openssl req -new -sha256 -config ${CONFIG} -key "${CERTDIR}/${CERT}.key" -out "${CERTDIR}/${CERT}.csr"

print_step "Verify CSR:"
openssl req -in "${CERTDIR}/${CERT}.csr" -noout -text
if [ $? -ne 0 ]; then
    print_error "Failed to verify CSR"
fi

print_step "You may now run ./sign-server-cert.sh ${TMP_NAMES} to get it signed"

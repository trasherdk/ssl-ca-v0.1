#!/bin/sh
##
##  new-user-cert.sh - create the user cert for personal use.
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved.
##

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) user@email.address.com"
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
    print_error "* Error: Missing CA directory..."
fi

# Check for root CA key
if [ ! -f "${CA}/ca.key" -o ! -f "${CA}/ca.crt" ]; then
    print_error "* Error: You must have root CA certificate generated first."
fi

CERTDIR="${BASE}/certs/users/${CERT}"
if [ ! -d "${CERTDIR}" ]; then
    mkdir -p "${CERTDIR}"
    chmod g-rwx,o-rwx "${CERTDIR}"
fi

if [ -f "${CERTDIR}/${CERT}.key" ]; then
    print_error "* A certificate for ${CERT} exist. Revoke and remove existing."
fi

print_step "No ${CERT}.key round. Generating one"
openssl genrsa -out "${CERTDIR}/${CERT}.key" ${KEYBITS}
if [ $? -ne 0 ]; then
    print_error "Failed to generate key"
fi

CONFIG="${CERTDIR}/config/user-cert.conf"

if [ ! -d $(dirname ${CONFIG}) ];then
    mkdir $(dirname ${CONFIG}) || exit 1
fi

cat >${CONFIG} <<EOT
[ req ]
default_bits                    = ${KEYBITS}
default_keyfile                = user.key
distinguished_name             = req_distinguished_name
string_mask                    = nombstr
req_extensions                 = v3_req

[ req_distinguished_name ]
commonName                     = Common Name (eg, John Doe)
commonName_default             = ${CERT}
commonName_max                 = 64
emailAddress                   = Email Address
emailAddress_default           = ${CERT}
emailAddress_max               = 64

[ v3_req ]
nsCertType                     = client,email
basicConstraints               = critical,CA:false
EOT

print_step "Fill in certificate data"
openssl req -new -config $CONFIG -key "${CERTDIR}/${CERT}.key" -out "${CERTDIR}/${CERT}.csr"
if [ $? -ne 0 ]; then
    print_error "Failed to generate certificate request"
fi

#rm -f $CONFIG

print_step "You may now run ./sign-user-cert.sh $CERT to get it signed"

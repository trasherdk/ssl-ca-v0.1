#!/bin/sh
##
##  sign-user-cert.sh - sign using our root CA the user cert
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved.
##

BASE=$(realpath $(dirname $0))
cd "${BASE}"

source "${BASE}/lib/helpers.sh" || exit 1

if [ $# -ne 1 ]; then
    print_error "Usage: $(basename $0) user@email.address.com"
fi

# Get the cert name
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

CERTDIR="${BASE}/certs/users/${CERT}"
if [ ! -d "${CERTDIR}" ]; then
    print_error "Missing CERTDIR - certs/${CERT}. This should be created by ./new-user-cert.sh"
fi

if [ ! -f "${CERTDIR}/${CERT}.csr" ]; then
    print_error "No $CERT.csr found. You must create that first."
fi

# Sign it with our CA key #

#   make sure environment exists
if [ ! -d "${CA}/ca.db.certs" ]; then
    print_error "Missing ca.db.certs file"
fi
if [ ! -f "${CA}/ca.db.serial" ]; then
    print_error "Missing ca.db.serial file"
fi
if [ ! -f "${CA}/ca.db.index" ]; then
    print_error "Missing ca.db.index file"
fi

#  create the CA requirement to sign the cert
CONFIG="${CERTDIR}/config/user-sign.conf"

if [ ! -d $(dirname ${CONFIG}) ]; then
    mkdir -p $(dirname ${CONFIG})
fi

cat >$CONFIG <<EOT
[ ca ]
default_ca              = default_CA
[ default_CA ]
dir                     = $CA
certs                   = \$dir
new_certs_dir           = \$dir/ca.db.certs
database                = \$dir/ca.db.index
serial                  = \$dir/ca.db.serial
RANDFILE                = \$dir/random-bits
certificate             = \$dir/ca.crt
private_key             = \$dir/ca.key
default_days            = 3650
default_crl_days        = 30
default_md              = sha256
preserve                = yes
x509_extensions		= user_cert
policy                  = policy_anything
[ policy_anything ]
commonName              = supplied
emailAddress            = supplied
[ user_cert ]
#SXNetID		= 3:yeak
subjectAltName		= email:copy
basicConstraints	= critical,CA:false
authorityKeyIdentifier	= keyid:always
extendedKeyUsage	= clientAuth,emailProtection
EOT

#  sign the certificate
print_step "CA signing: ${CERT}.csr -> ${CERT}.crt:"
openssl ca -config $CONFIG -out "${CERTDIR}/$CERT.crt" -infiles "${CERTDIR}/$CERT.csr"
if [ $? -ne 0 ]; then
    print_error "Failed to sign certificate"
fi
print_success "Certificate signed successfully"

print_step "CA verifying: $CERT.crt <-> CA cert"
openssl verify -CAfile "$CA/ca.crt" "${CERTDIR}/$CERT.crt"
if [ $? -ne 0 ]; then
    print_error "Failed to verify certificate"
fi
print_success "Certificate verified successfully"

#  cleanup after SSLeay
rm -f $CONFIG
# rm -f ${CERTDIR}/$CERT.csr
rm -f $CA/ca.db.serial.old
rm -f $CA/ca.db.index.old


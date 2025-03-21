#!/bin/sh
##
##  sign-user-cert.sh - sign using our root CA the user cert
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved.
##

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) user@email.address.com"
    exit 1
fi

BASE=$(realpath $(dirname $0))
cd "${BASE}"

# Get the cert name
CERT=$1
shift

CA="${BASE}/CA"
if [ ! -d ${CA} ]; then
    echo "* Error: Missing CA directory..."
    exit 1
fi

# Check for root CA key
if [ ! -f "${CA}/ca.key" -o ! -f "${CA}/ca.crt" ]; then
    echo "Error: You must have root CA certificate generated first."
    exit 1
fi

CERTDIR="${BASE}/certs/users/${CERT}"
if [ ! -d "${CERTDIR}" ]; then
    echo "Error: Missing CERTDIR - certs/${CERT}"
    echo "This should be created by ./new-user-cert.sh"
    exit 1
fi

if [ ! -f "${CERTDIR}/${CERT}.csr" ]; then
    echo "No $CERT.csr round. You must create that first."
    exit 1
fi

# Sign it with our CA key #

#   make sure environment exists
if [ ! -d "${CA}/ca.db.certs" ]; then
    echo "Error: Missing ca.db.certs file"
    exit 1
    # mkdir "${CA}/ca.db.certs"
fi
if [ ! -f "${CA}/ca.db.serial" ]; then
    echo "Error: Missing ca.db.serial file"
    exit 1
    # echo '01' >"${CA}/ca.db.serial"
fi
if [ ! -f "${CA}/ca.db.index" ]; then
    echo "Error: Missing ca.db.index file"
    exit 1
    # cp /dev/null "${CA}/ca.db.index"
fi

#  create the CA requirement to sign the cert

CONFIG="${BASE}/config/ca.config"

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
echo "CA signing: ${CERT}.csr -> ${CERT}.crt:"
openssl ca -config $CONFIG -out "${CERTDIR}/$CERT.crt" -infiles "${CERTDIR}/$CERT.csr"
echo "CA verifying: $CERT.crt <-> CA cert"
openssl verify -CAfile "$CA/ca.crt" "${CERTDIR}/$CERT.crt"

#  cleanup after SSLeay
rm -f $CONFIG
# rm -f ${CERTDIR}/$CERT.csr
rm -f $CA/ca.db.serial.old
rm -f $CA/ca.db.index.old


#!/bin/sh
##
##  sign-server-cert.sh - sign using our root CA the server cert
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

CERT=$1
shift

CA="${BASE}/CA"
if [ ! -d ${CA} ]; then
    print_error "Missing CA directory..."
fi

# Check for root CA key
if [ ! -f "${CA}/ca.key" -o ! -f "${CA}/ca.crt" ]; then
    print_error "You must have root CA key generated first."
fi

#   make sure environment exists
if [ ! -d "$CA/ca.db.certs" ]; then
    print_error "Missing CA directory ca.db.certs"
fi

if [ ! -f "$CA/ca.db.serial" ]; then
    print_error "Missing CA database file ca.db.serial"
fi

if [ ! -f "$CA/ca.db.index" ]; then
    print_error "Missing CA database file ca.db.index"
fi

# Check for certificate directory
CERTDIR="${BASE}/certs/${CERT}"
if [ ! -d "${CERTDIR}" ]; then
    print_error "Missing certificate directory for ${CERT}..."
fi

if [ ! -f "${CERTDIR}/${CERT}.csr" ]; then
    print_error "No $CERT.csr Found. You must create that first."
fi

#  create the CA requirement to sign the cert
CONFIG="${CERTDIR}/config/server-sign.conf"

if [ ! -d $(dirname ${CONFIG}) ];then
    mkdir -p $(dirname ${CONFIG})
fi

cat >$CONFIG <<EOT
[ ca ]
default_ca              = default_CA
[ default_CA ]
dir                     = ${CA}
certs                   = \$dir
new_certs_dir           = \$dir/ca.db.certs
database                = \$dir/ca.db.index
serial                  = \$dir/ca.db.serial
RANDFILE                = \$dir/random-bits
certificate             = \$dir/ca.crt
private_key             = \$dir/ca.key
default_days            = ${VALID_DAYS}
default_crl_days        = 30
default_md              = ${HASHALGO}
preserve                = no
x509_extensions			= server_cert
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
#subjectKeyIdentifier	= hash
authorityKeyIdentifier	= keyid:always
extendedKeyUsage		= serverAuth,clientAuth,msSGC,nsSGC
basicConstraints		= critical,CA:false
subjectAltName			= @alt_names
[ alt_names ]
DNS.1					= ${CERT}
EOT

CNT=2
ALT_NAMES=""
TMP_NAMES="${CERT}"

while [ $# -gt 0 ]
do
	ALT_NAMES="${ALT_NAMES}DNS.${CNT}										= ${1}\n"
	TMP_NAMES="${TMP_NAMES} ${1}"
	((CNT++))
	shift
done
echo -e "${ALT_NAMES}" >> ${CONFIG}

#  sign the certificate
print_step "CA signing: ${CERT}.csr -> ${CERT}.crt:"
openssl ca -config "${CONFIG}" -out "${CERTDIR}/${CERT}.crt" -infiles "${CERTDIR}/${CERT}.csr"
if [ $? -ne 0 ]; then
    print_error "Failed to sign certificate"
fi
print_success "Certificate signed successfully"

print_step "CA verifying: ${CERT}.crt <-> CA cert"
openssl verify -CAfile "${CA}/ca.crt" "${CERTDIR}/${CERT}.crt"
if [ $? -ne 0 ]; then
    print_error "Failed to verify certificate"
fi
print_success "Certificate verified successfully"

for F in ${TMP_NAMES}
do
  print_step "Verifying domain ${F} in certificate"
  openssl x509 -in "${CERTDIR}/${CERT}.crt" -noout -text | grep -q "DNS:${F}"
  if [ $? -ne 0 ]; then
    print_error "Domain ${F} not found in certificate"
  fi
  print_success "Domain ${F} found in certificate"
done

#  cleanup after SSLeay
#rm -f $CONFIG
#rm -f $CERT.csr
rm -f $CA/ca.db.serial.old
rm -f $CA/ca.db.index.old


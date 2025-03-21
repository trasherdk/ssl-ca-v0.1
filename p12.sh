#!/bin/sh
##
##  p12.sh - Collect the user certs and pack into pkcs12 format
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved.
##
BASE=$(dirname $(realpath $0))
cd ${BASE}

if [ $# -ne 1 ]; then
        echo "Usage: $0 username"
        exit 1
fi

CERT=$1
shift

CA="${BASE}/CA"

CERTDIR="${BASE}/certs/users/${CERT}"
if [ ! -d ${CERTDIR} ]; then
	mkdir -p ${CERTDIR} || exit 1
fi

echo "* Check for requirements..."
[ -f  "${CERTDIR}/${CERT}.key" ] || { echo "${CERT}.key Not found..."; exit 1; }
[ -f  "${CERTDIR}/${CERT}.crt" ] || { echo "${CERT}.crt Not found..."; exit 1; }
[ -f  "${CA}/ca.crt" ] || { echo "${CA}/ca.crt Not found..."; exit 1; }

if [ ! -f "${CERTDIR}/${CERT}.key" -o ! -f "${CERTDIR}/${CERT}.crt" -o ! -f "${CA}/ca.crt" ]; then
	echo ""
	echo "Cannot proceed because:"
	echo "1. Must have root CA certification"
	echo "2. Must have ${CERT}.key"
	echo "3. Must have ${CERT}.crt"
	echo ""
	exit 1
fi

username="$(openssl x509 -noout  -in "${CERTDIR}/${CERT}.crt" -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;')"
caname="$(openssl x509 -noout  -in "${CA}/ca.crt" -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;')"

# Package it.
openssl pkcs12 \
	-export \
	-in "${CERTDIR}/${CERT}.crt" \
	-inkey "${CERTDIR}/${CERT}.key" \
	-certfile "${CA}/ca.crt" \
	-name "$username" \
	-caname "$caname" \
	-out "${CERTDIR}/${CERT}.p12"

echo "File: ${CERTDIR}/${CERT}.p12"
echo "The certificate for ${CERT} has been collected into a pkcs12 file."
echo "You can download to your browser and import it."
echo ""

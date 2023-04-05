#!/bin/sh
##
##  p12.sh - Collect the user certs and pack into pkcs12 format
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved. 
##
CWD=$(dirname $(realpath $0))

CERT=$1
CA="${CWD}/CA"

if [ $# -ne 1 ]; then
        echo "Usage: $0 user@email.address.com"
        exit 1
fi

echo "* Check for requirements..."
[ -f  $CWD/$CERT.key ] || { echo "$CERT.key Not found..."; exit 1; }
[ -f  $CWD/$CERT.crt ] || { echo "$CERT.crt Not found..."; exit 1; }
[ -f  $CA/ca.crt ] || { echo "$CA/ca.crt Not found..."; exit 1; }

if [ ! -f $CWD/$CERT.key -o ! -f $CWD/$CERT.crt -o ! -f "$CA/ca.crt" ]; then
	echo ""
	echo "Cannot proceed because:"
	echo "1. Must have root CA certification"
	echo "2. Must have $CERT.key"
	echo "3. Must have $CERT.crt"
	echo ""
	exit 1
fi

username="`openssl x509 -noout  -in $CERT.crt -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;'`"
caname="`openssl x509 -noout  -in $CA/ca.crt -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;'`"

# Package it.
openssl pkcs12 \
	-export \
	-in "$CERT.crt" \
	-inkey "$CERT.key" \
	-certfile "$CA/ca.crt" \
	-name "$username" \
	-caname "$caname" \
	-out $CERT.p12

echo "File: $CERT.p12"
echo "The certificate for $CERT has been collected into a pkcs12 file."
echo "You can download to your browser and import it."
echo ""

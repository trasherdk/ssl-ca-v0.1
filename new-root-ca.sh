#!/bin/sh
##
##  new-root-ca.sh - create the root CA
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved. 
##

BASE=$(realpath $(dirname $0))
cd ${BASE}

# Create root CA directory
CA="${BASE}/CA"
if [ ! -d ${CA}]; then
	mkdir "${CA}"
	chmod g-rwx,o-rwx "${CA}"
fi

# Create the master CA key. This should be done once.
if [ ! -f "${CA}/ca.key" ]; then
	echo "No Root CA key round. Generating one"
	dd if=/dev/urandom of="${CA}/random-bits" bs=2K count=1
	openssl genrsa -des3 -out "${CA}/ca.key" 2048 -rand "${CA}/random-bits"
	echo ""
fi

# Create config directory
if [ ! -d "${BASE}/config" ]; then
	mkdir "${BASE}/config"
	chmod g-rwx,o-rwx "${BASE}/config"
fi

CONFIG="${BASE}/config/root-ca.conf"
cat >$CONFIG <<EOT
[ req ]
default_bits				= 2048
default_keyfile			= \$CA/ca.key
distinguished_name	= req_distinguished_name
x509_extensions			= v3_ca
string_mask					= nombstr
req_extensions			= v3_req
[ req_distinguished_name ]
countryName					= Country Name (2 letter code)
countryName_default	= DK
countryName_min			= 2
countryName_max			= 2
stateOrProvinceName	= State or Province Name (full name)
stateOrProvinceName_default	= Denmark
localityName				= Locality Name (eg, city)
localityName_default	= Copenhagen
0.organizationName		= Organization Name (eg, company)
0.organizationName_default	= Trader Internet
organizationalUnitName	= Organizational Unit Name (eg, section)
organizationalUnitName_default	= Certification Services Division
commonName					= Common Name (eg, MD Root CA)
commonName_max			= 64
commonName_default	= Trader Internet Root CA
emailAddress				= Email Address
emailAddress_default	= hostmaster@fumlersoft.dk
emailAddress_max		= 40
[ v3_ca ]
basicConstraints		= critical,CA:true
subjectKeyIdentifier	= hash
[ v3_req ]
nsCertType					= objsign,email,server
EOT

echo "Self-sign the root CA..."
openssl req -new -x509 -days 3650 -config $CONFIG -key "$CA/ca.key" -out "$CA/ca.crt"

#rm -f $CONFIG

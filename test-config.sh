#!/bin/bash

BASE=$(realpath $(dirname $0))
cd ${BASE}

CERT=$1
shift

CONFIG="${BASE}/config/server-cert.conf"

cat >$CONFIG <<EOT
[ req ]
default_bits										= 2048
default_keyfile									= server.key
distinguished_name							= req_distinguished_name
string_mask											= nombstr
req_extensions									= v3_req
[ req_distinguished_name ]
countryName											= Country Name (2 letter code)
countryName_default							= DK
countryName_min									= 2
countryName_max									= 2
stateOrProvinceName							= State or Province Name (full name)
stateOrProvinceName_default			= Denmark
localityName										= Locality Name (eg, city)
localityName_default						= Copenhagen
0.organizationName							= Organization Name (eg, company)
0.organizationName_default			= Trader Internet
organizationalUnitName					= Organizational Unit Name (eg, section)
organizationalUnitName_default	= Secure Server
commonName											= Common Name (eg, www.domain.com)
commonName_default							= $CERT
commonName_max									= 64
emailAddress										= Email Address
emailAddress_default						= hostmaster@fumlersoft.dk
emailAddress_max								= 40
[ v3_req ]
nsCertType											= server
basicConstraints								= critical,CA:false
EOT

#!/bin/bash

BASE=$(realpath $(dirname $0))
cd ${BASE}

CA="${BASE}/CA"
CONFIG="${BASE}/config/root-ca.conf"

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
default_days            = 3650
default_crl_days        = 30
default_md              = sha256
preserve                = no
x509_extensions		      = server_cert
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
extendedKeyUsage	= serverAuth,clientAuth,msSGC,nsSGC
basicConstraints	= critical,CA:false
EOT

exit 0

cat >$CONFIG <<EOT
[ ca ]
default_ca	= CA_default		# The default ca section

[ CA_default ]
dir						= ${CA}
[ req ]
default_bits				= 2048
default_keyfile			= \$dir/ca.key
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

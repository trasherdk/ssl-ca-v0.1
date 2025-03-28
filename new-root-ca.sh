#!/bin/bash
##
##  new-root-ca.sh - create the root CA
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved.
##

# Dynamically detect the working directory as the root
BASE=$(realpath $(dirname $0))
cd "${BASE}" || exit 1

CA="${BASE}/CA"

# Check if the root certificate already exists
if [ -f "$CA/ca.crt" ]; then
    echo "ERROR: A root CA certificate already exists in this directory ($CA/ca.crt)."
    echo "This script must only be run in a directory where no CA certificate exists."
    echo "If you need to create a Sub-CA, use the appropriate scripts: ./new-sub-ca.sh <sub-ca-name>."
	echo "If you want to create a new root CA, please remove the existing certificate and try again."
    exit 1
fi

# Create root CA directory
if [ ! -d ${CA} ]; then
	mkdir "${CA}" || exit 1
	chmod g-rwx,o-rwx "${CA}"
	mkdir "${CA}/ca.db.certs"
	echo "01" > "${CA}/ca.db.serial"
	touch "${CA}/ca.db.index"
fi

KEYBITS=4096
HASHALGO="sha256"
VALID_DAYS=3650
RANDOM_SRC=/dev/urandom

# Create the master CA key. This should be done once.
if [ ! -f "${CA}/ca.key" ]; then
	echo "No Root CA key round. Generating one"
	# dd if=/dev/urandom of="${CA}/random-bits" bs=4K count=1 || exit 1
	openssl genrsa -aes256 -out "${CA}/ca.key" -rand "${RANDOM_SRC}" ${KEYBITS} || exit 1
	echo ""
fi

# Create config directory
if [ ! -d "${BASE}/config" ]; then
	mkdir "${BASE}/config"
	chmod g-rwx,o-rwx "${BASE}/config"
fi

# Add the v3_restricted_sub_ca extension to the root-ca.conf configuration
CONFIG="${BASE}/config/root-ca.conf"
cat >$CONFIG <<EOT
[ ca ]
default_ca = CA_default

[ CA_default ]
dir                     = ./CA
certs                   = \$dir/ca.db.certs
database                = \$dir/ca.db.index
new_certs_dir           = \$dir/ca.db.certs
certificate             = \$dir/ca.crt
serial                  = \$dir/ca.db.serial
private_key             = \$dir/ca.key
default_days            = 3650
default_md              = sha256
policy                  = policy_match
email_in_dn             = no
rand_serial             = yes

[ policy_match ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
dir                     = ${CA}
default_bits            = 4096
default_keyfile         = \$dir/ca.key
distinguished_name      = req_distinguished_name
x509_extensions         = v3_ca
string_mask             = nombstr
req_extensions          = v3_req

[ req_distinguished_name ]
countryName             = Country Name (2 letter code)
countryName_default     = DK
countryName_min         = 2
countryName_max         = 2
stateOrProvinceName     = State or Province Name (full name)
stateOrProvinceName_default = Denmark
localityName            = Locality Name (eg, city)
localityName_default    = Copenhagen
0.organizationName      = Organization Name (eg, company)
0.organizationName_default = Trader Internet
organizationalUnitName  = Organizational Unit Name (eg, section)
organizationalUnitName_default = Certification Services Division
commonName              = Common Name (eg, MD Root CA)
commonName_max          = 64
commonName_default      = Trader Internet Root CA
emailAddress            = Email Address
emailAddress_default    = hostmaster@fumlersoft.dk
emailAddress_max        = 40

[ v3_ca ]
basicConstraints        = critical,CA:true
keyUsage                = critical,keyCertSign,cRLSign
subjectKeyIdentifier    = hash

[ v3_req ]
nsCertType              = objsign,email,server

[ v3_sub_ca ]
basicConstraints        = critical,CA:true
keyUsage                = critical,keyCertSign,cRLSign
subjectKeyIdentifier    = hash

[ v3_restricted_sub_ca ]
basicConstraints        = critical,CA:false
keyUsage                = critical,digitalSignature,keyEncipherment
subjectKeyIdentifier    = hash
EOT

# Debugging output to confirm serial number file creation
echo "Checking if serial number file exists..."
if [ ! -f "${CA}/ca.db.serial" ]; then
    echo "Serial number file not found. Initializing..."
    echo "01" > "${CA}/ca.db.serial"
    echo "Serial number file initialized with value: 01"
else
    echo "Serial number file already exists."
fi

echo "Self-sign the root CA..."
openssl req -new -x509 -days 3650 -config $CONFIG -key "$CA/ca.key" -out "$CA/ca.crt"

#rm -f $CONFIG

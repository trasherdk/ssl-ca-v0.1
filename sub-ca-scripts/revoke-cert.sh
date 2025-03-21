#!/bin/bash
##
##  revoke-cert.sh - revoke a certificate issued by a sub-CA
##

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) <www.domain.com>"
    exit 1
fi

BASE=$(realpath $(dirname $0)/..)
SUB_CA_DIR="${BASE}/sub-CAs/<sub-ca-name>"
CA_DIR="${SUB_CA_DIR}/CA"

# Ensure sub-CA exists
if [ ! -f "${CA_DIR}/${SUB_CA_NAME}.key" ] || [ ! -f "${CA_DIR}/${SUB_CA_NAME}.crt" ]; then
    echo "Error: Sub-CA must be created first."
    exit 1
fi

CERT=$1
INDEX="${CA_DIR}/ca.db.index"
PEMDIR="${CA_DIR}/ca.db.certs"
REVOKED="${SUB_CA_DIR}/certs-revoked"

# Ensure index file exists
if [ ! -f "${INDEX}" ]; then
    echo "Error: Missing CA database index file (${INDEX})."
    exit 1
fi

declare -A LIST
exec 3<&0
exec 0<"${INDEX}"

CNT=0
while read LINE; do
    # Skip already revoked certificates
    if [ "$(echo "${LINE}" | cut -f1)" = "R" ]; then
        continue
    fi

    PEMINDEX=$(echo "${LINE}" | cut -f4)
    CN=$(echo "${LINE}" | grep -o "CN=[^/]*" | cut -d'=' -f2)
    if [ "${CN}" = "${CERT}" ]; then
        ((CNT++))
        LIST[${CNT},hexIndex]="${PEMINDEX}"
        LIST[${CNT},commonName]="${CN}"
        echo -e "\t${CNT}: ${PEMINDEX} ${CN}"
    fi
done
exec 0<&3

if [ ${CNT} -eq 0 ]; then
    echo "No certificate found matching ${CERT}."
    exit 0
fi

echo -n "Enter the number of the certificate you wish to revoke (0 to cancel): "
read ANSWER
if [ "${ANSWER}" = "0" ] || [ -z "${LIST[${ANSWER},hexIndex]}" ]; then
    echo "Operation canceled."
    exit 0
fi

PEMINDEX="${LIST[${ANSWER},hexIndex]}"
CN="${LIST[${ANSWER},commonName]}"

if [ ! -f "${PEMDIR}/${PEMINDEX}.pem" ]; then
    echo "Error: Certificate file not found (${PEMINDEX}.pem)."
    exit 1
fi

# Revoke the certificate
CONFIG="${SUB_CA_DIR}/config/revoke-${PEMINDEX}-ca.config"
cat >"${CONFIG}" <<EOT
[ ca ]
default_ca              = default_CA
[ default_CA ]
dir                     = ${CA_DIR}
certs                   = \$dir/ca.db.certs
new_certs_dir           = \$dir/ca.db.certs
database                = \$dir/ca.db.index
serial                  = \$dir/ca.db.serial
RANDFILE                = \$dir/random-bits
certificate             = \$dir/${SUB_CA_NAME}.crt
private_key             = \$dir/${SUB_CA_NAME}.key
default_days            = 3650
default_md              = sha256
preserve                = yes
x509_extensions         = user_cert
policy                  = policy_anything
[ user_cert ]
basicConstraints        = critical,CA:false
authorityKeyIdentifier  = keyid:always
EOT

openssl ca -config "${CONFIG}" -revoke "${PEMDIR}/${PEMINDEX}.pem" || exit 1

# Move revoked certificate
if [ ! -d "${REVOKED}" ]; then
    mkdir -p "${REVOKED}"
fi
mv "${PEMDIR}/${PEMINDEX}.pem" "${REVOKED}/${CN}-${PEMINDEX}.pem"

# Cleanup
rm -f "${CONFIG}"
rm -f "${CA_DIR}/ca.db.serial.old"
rm -f "${CA_DIR}/ca.db.index.old"

echo "Certificate ${CN} (${PEMINDEX}) has been revoked."

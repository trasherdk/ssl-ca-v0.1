# Source helpers for color variables
if [ -f "${BASE}/lib/helpers.sh" ]; then
    source ${BASE}/lib/helpers.sh
fi

function move_revoked_cert() {

  mkdir -p ${REVOKED} || { echo "Error: Failed to create REVOKED directory ${REVOKED}"; return 1; }

  if [ -d ${CERTS}/${CN} ];then
    echo "${GREEN}Moveing ${CN} to ${CN}-${PEMINDEX}${RESTORE}"
    # Remove destination if it already exists (e.g., from previous test run)
    if [ -d ${REVOKED}/${CN}-${PEMINDEX} ]; then
      rm -rf ${REVOKED}/${CN}-${PEMINDEX}
    fi
    mv ${CERTS}/${CN} ${REVOKED}/${CN}-${PEMINDEX} || { echo "Error: Failed to move ${CERTS}/${CN} to ${REVOKED}/${CN}-${PEMINDEX}"; return 1; }
  else
    echo "${RED}${CN} Not found. Creating ${CN}-${PEMINDEX} directory${RESTORE}"
    mkdir -p ${REVOKED}/${CN}-${PEMINDEX}
  fi

}

function revoke_cert() {

	CONFIG="${BASE}/config/revoke-${PEMINDEX}-ca.config"

	cat >${CONFIG} <<EOT
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

	openssl ca -config ${CONFIG} -revoke "${PEMDIR}/${PEMINDEX}.pem" || return 1
	regenerate_ca_crl "${BASE}" || return 1

	#  cleanup after SSLeay 
	#rm -f ${CONFIG}
	rm -f ${CA}/ca.db.serial.old
	rm -f ${CA}/ca.db.index.old
	#rm -f ${PEM}/${CERT}.pem
}

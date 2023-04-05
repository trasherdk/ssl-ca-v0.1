function move_revoked_cert() {
 
  if [ -d ${CERTS}/${CN} ];then
    echo "${GREEN}Moveing ${CN} to ${CN}-${PEMINDEX}${RESTORE}"
    mv ${CERTS}/${CN} ${REVOKED}/${CN}-${PEMINDEX}
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

	#  cleanup after SSLeay 
	#rm -f ${CONFIG}
	rm -f ${CA}/ca.db.serial.old
	rm -f ${CA}/ca.db.index.old
	#rm -f ${PEM}/${CERT}.pem
}

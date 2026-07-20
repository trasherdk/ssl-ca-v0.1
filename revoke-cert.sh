#!/bin/bash
##
##  revoke-cert.sh - revoke a cert issued by our root CA
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved.
##

if [ $# -gt 0 ]; then
    # Join all parameters into a single CN string
    CERT="$*"
else
    CERT=""
fi

BASE=$(realpath $(dirname $0))
cd ${BASE}

CA="${BASE}/CA"
if [ ! -d ${CA} ]; then
    echo "* Error: Missing CA directory..."
    exit 1
fi

INDEX=${CA}/ca.db.index
PEMDIR="${CA}/ca.db.certs"
CERTS=${BASE}/certs
REVOKED=${CERTS}-revoked

echo "CA Path: ${CA}"

declare -A LIST

exec 3<&0
exec 0<${INDEX}

CNT=0

while read LINE;do

    if [ "$(echo "${LINE}" | cut -f1 )" = "R" ];then
        continue
    fi

    PEMINDEX=$(echo "${LINE}" | cut -f4 )
    CERT_TYPE=$(echo "${LINE}" | cut -f5 )

    CN=$( echo "${LINE}" | egrep -o "CN=([^/]+)" | cut -f2 -d'=' )
    EM=$( echo "${LINE}" | egrep -o "emailAddress=(.*)" | cut -f2 -d'=' )
    if [ -z "${CERT}" ] || [ "${CN}" = "${CERT}" ];then
        ((CNT++))
        LIST[${CNT},hexIndex]=${PEMINDEX}
        LIST[${CNT},commonName]=${CN}
        LIST[${CNT},emailAddress]=${EM}
        echo -e "\t${WHITE}${CNT}:\t${YELLOW}${PEMINDEX}${CYAN} [${CERT_TYPE}] ${CN} ${EM}${RESTORE}"
    fi
done

exec 0<&3

if [ ${CNT} -gt 0 ];then
    # If no CERT parameter was provided, just list and exit
    if [ -z "${CERT}" ]; then
        echo -e "\n\t${WHITE}Found ${CNT} unrevoked certificate(s).${RESTORE}\n"
        exit 0
    fi
    echo -e "\n\t\t${WHITE}Enter 0 (zero) to cancel${RESTORE}\n"
else
    echo -e "\n\t${WHITE} No certificate found matching ${CYAN}${CERT}${RESTORE}\n"
    exit 0
fi

#echo "${YELLOW}${PEMINDEX} ${CN} ${EM}"
echo -ne "\t${WHITE}Enter the number of the certificate yoy wish to revoke ? ${RESTORE}: "
read ANSWER
echo ""
if [ ! "${LIST[${ANSWER},hexIndex]}" = "" ];then
    
    PEMINDEX=${LIST[${ANSWER},hexIndex]}
    CN=${LIST[${ANSWER},commonName]}
    EM=${LIST[${ANSWER},emailAddress]}
    
    if [ ! -f ${PEMDIR}/${PEMINDEX}.pem ];then
        echo -e "\n${RED} File not found:${CYAN} ${PEMINDEX}.pem ${RESTORE}\n"
        exit 1
    fi
    
    source ${BASE}/scripts/revoke.sh
    
    echo -e "${WHITE} Revoking ${ANSWER}: ${YELLOW}${PEMINDEX}${CYAN} ${CN} ${EM}${RESTORE}\n"
    revoke_cert || exit 1
    move_revoked_cert
fi

exit 0


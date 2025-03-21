#!/bin/bash

BASE=$(realpath $(dirname $0))
cd "${BASE}"

CA=${BASE}/CA
INDEX=${CA}/ca.db.index
PEMDIR=${CA}/ca.db.certs
CERTS=${BASE}/certs
REVOKED=${CERTS}-revoked

exec 3<&0
exec 0<${INDEX}

while read LINE;do

  if [ "$(echo "${LINE}" | cut -f1 )" = "V" ];then
    continue
  fi

  PEMINDEX=$(echo "${LINE}" | cut -f4 )

  CN=$( echo "${LINE}" | egrep -o "CN=(.*)/" | cut -f2 -d'=' | cut -f1 -d'/' )
  echo -n "${YELLOW}${PEMINDEX} ${CN} "
  
  if [ -d ${CERTS}/${CN} ];then
    echo "${GREEN}Moveing ${CN} to ${CN}-${PEMINDEX}${RESTORE}"
    mv ${CERTS}/${CN} ${REVOKED}/${CN}-${PEMINDEX}
  else
    echo "${RED}${CN} Not found. Creating ${CN}-${PEMINDEX} directory${RESTORE}"
    mkdir -p ${REVOKED}/${CN}-${PEMINDEX}
  fi
done

exec 0<&3

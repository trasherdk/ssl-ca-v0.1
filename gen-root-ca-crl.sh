#!/bin/bash


BASE=$(realpath "$(dirname "$0")")
cd "${BASE}" || exit 1

CA="${BASE}/CA"
CONFIG="${BASE}/config/root-ca.conf"
CRL="${BASE}/CRL/root-ca.crl.pem"

if [ ! -d "$(dirname "${CRL}")" ]; then
  mkdir "$(dirname "${CRL}")" || exit 1
fi

openssl ca -config "${CONFIG}" \
  -gencrl -out "${CRL}"

if [ -f "${CRL}" ]; then
  openssl crl -in "${CRL}" -noout -text
fi
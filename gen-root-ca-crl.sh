#!/bin/bash


BASE=$(realpath "$(dirname "$0")")
cd "${BASE}" || exit 1

CA="${BASE}/CA"
CONFIG="${BASE}/config/root-ca.conf"
CRL="${BASE}/CRL/root-ca.crl.pem"

if [ ! -d "${CA}" ]; then
  echo "[ERROR] CA directory not found at ${CA}"
  exit 1
fi
if [ ! -d "$(dirname "${CRL}")" ]; then
  mkdir "$(dirname "${CRL}")" || exit 1
fi

# Determine CRL validity period
# Prefer value from config (default_crl_days), else fall back to DEFAULT_CRL_DAYS env or 90
CRL_DAYS=""
if grep -Eq '^[[:space:]]*default_crl_days[[:space:]]*=' "${CONFIG}"; then
  CRL_DAYS=$(awk -F= '/^[[:space:]]*default_crl_days[[:space:]]*=/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "${CONFIG}")
fi
if [ -z "${CRL_DAYS}" ]; then
  CRL_DAYS="${DEFAULT_CRL_DAYS:-90}"
fi

# Support non-interactive passphrase via environment
PASSIN_ARGS=()
if [ -n "${OPENSSL_PASSIN:-}" ]; then
  PASSIN_ARGS=(-passin "${OPENSSL_PASSIN}")
elif [ -n "${CA_PASSPHRASE:-}" ]; then
  PASSIN_ARGS=(-passin "pass:${CA_PASSPHRASE}")
fi

openssl ca -config "${CONFIG}" \
  -gencrl -crldays "${CRL_DAYS}" -out "${CRL}" \
  "${PASSIN_ARGS[@]}"

if [ -f "${CRL}" ]; then
  openssl crl -in "${CRL}" -noout -text
fi
#!/bin/bash
##
##  renew-sub-ca.sh - renew a sub-CA certificate
##
##  Uses config/root-ca.conf and selects the extension section from the
##  certificate being renewed. The CSR is built from that certificate, so
##  renewal does not depend on the request config deleted by new-sub-ca.sh.

if [ $# -ne 1 ]; then
    echo "Usage: $(basename "$0") <sub-ca-name>"
    exit 1
fi

BASE=$(realpath "$(dirname "$0")")
cd "${BASE}" || exit 1
source "${BASE}/lib/helpers.sh" || exit 1

SUB_CA_NAME=$1
SUB_CA_DIR="${BASE}/sub-CAs/${SUB_CA_NAME}"
SUB_CA_CA_DIR="${SUB_CA_DIR}/CA"
ROOT_CA_DIR="${BASE}/CA"
ROOT_CA_CONFIG="${BASE}/config/root-ca.conf"
SUB_CA_KEY="${SUB_CA_CA_DIR}/ca.key"
SUB_CA_CERT="${SUB_CA_CA_DIR}/ca.crt"
CSR="${SUB_CA_CA_DIR}/${SUB_CA_NAME}.csr"
REGISTRY_CERT="${BASE}/certs/sub-CAs/${SUB_CA_NAME}/${SUB_CA_NAME}/ca.crt"

if [ ! -f "${SUB_CA_KEY}" ] || [ ! -f "${SUB_CA_CERT}" ]; then
    echo "Error: Sub-CA must exist to renew (${SUB_CA_KEY}, ${SUB_CA_CERT})."
    exit 1
fi
if [ ! -f "${ROOT_CA_DIR}/ca.key" ] || [ ! -f "${ROOT_CA_DIR}/ca.crt" ] || [ ! -f "${ROOT_CA_CONFIG}" ]; then
    echo "Error: Signing CA key, certificate, or ${ROOT_CA_CONFIG} is missing."
    exit 1
fi

SUB_CA_EXTENSION="v3_sub_ca"
cert_text=$(openssl x509 -in "${SUB_CA_CERT}" -text -noout) || exit 1
if echo "${cert_text}" | grep -q "pathlen:0"; then
    SUB_CA_EXTENSION="v3_restricted_sub_ca"
fi

BACKUP_DIR="${SUB_CA_CA_DIR}/backup"
mkdir -p "${BACKUP_DIR}"
BACKUP_CERT="${BACKUP_DIR}/ca.crt.$(date +%Y%m%d%H%M%S)"
cp "${SUB_CA_CERT}" "${BACKUP_CERT}"

echo "Generating CSR for sub-CA renewal from the current certificate..."
set_key_pass_args passin
if ! openssl x509 -x509toreq -in "${SUB_CA_CERT}" -signkey "${SUB_CA_KEY}" "${KEY_PASS_ARGS[@]}" -out "${CSR}"; then
    echo "Error: Failed to build a renewal CSR from ${SUB_CA_CERT}."
    exit 1
fi

# The live certificate is still valid in the CA index. Allow a second
# certificate with the same subject for this invocation only.
SIGN_CONFIG=$(mktemp)
awk '
    /^\[ CA_default \]/ { print; print "unique_subject        = no"; next }
    { print }
' "${ROOT_CA_CONFIG}" > "${SIGN_CONFIG}"

load_ca_env "${BASE}/.env"
require_crl_url

echo "Signing renewed sub-CA certificate with extension ${SUB_CA_EXTENSION}..."
if ! openssl ca -config "${SIGN_CONFIG}" -extensions "${SUB_CA_EXTENSION}" -days 3650 \
    -in "${CSR}" -out "${SUB_CA_CERT}" -keyfile "${ROOT_CA_DIR}/ca.key" \
    -cert "${ROOT_CA_DIR}/ca.crt"; then
    echo "Error: Failed to sign renewed sub-CA certificate. Restoring backup."
    cp "${BACKUP_CERT}" "${SUB_CA_CERT}"
    rm -f "${CSR}" "${SIGN_CONFIG}"
    exit 1
fi
rm -f "${SIGN_CONFIG}"

update_ca_index_type "${ROOT_CA_DIR}" "subca"

echo "Appending signing CA certificate..."
cat "${ROOT_CA_DIR}/ca.crt" >> "${SUB_CA_CERT}"

if ! openssl verify -CAfile "${SUB_CA_CERT}" "${SUB_CA_CERT}" > "${SUB_CA_CA_DIR}/ca-verify.log" 2>&1; then
    echo "Error: Renewed sub-CA certificate validation failed. Restoring backup."
    echo "See ${SUB_CA_CA_DIR}/ca-verify.log"
    cp "${BACKUP_CERT}" "${SUB_CA_CERT}"
    rm -f "${CSR}"
    exit 1
fi

if [ -d "$(dirname "${REGISTRY_CERT}")" ]; then
    cp "${SUB_CA_CERT}" "${REGISTRY_CERT}"
fi

rm -f "${CSR}"

echo "Sub-CA certificate renewed: ${SUB_CA_CERT}"
echo "Backup of the old certificate is stored in: ${BACKUP_DIR}"

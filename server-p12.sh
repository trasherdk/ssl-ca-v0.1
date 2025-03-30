#!/bin/sh
##
##  server-p12.sh - Pack server certificate into PKCS#12 format
##

BASE=$(dirname $(realpath $0))
cd ${BASE}

source "${BASE}/lib/helpers.sh" || exit 1

if [ $# -ne 1 ]; then
        print_error "Usage: $0 servername"
fi

SERVER=$1
shift

CA="${BASE}/CA"
CERTDIR="${BASE}/certs/${SERVER}"

print_step "Checking for requirements..."
[ -f  "${CERTDIR}/${SERVER}.key" ] || { print_error "${SERVER}.key Not found..."; }
[ -f  "${CERTDIR}/${SERVER}.crt" ] || { print_error "${SERVER}.crt Not found..."; }
[ -f  "${CA}/ca.crt" ] || { print_error "${CA}/ca.crt Not found..."; }



servername="$(openssl x509 -noout  -in "${CERTDIR}/${SERVER}.crt" -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;')"
caname="$(openssl x509 -noout  -in "${CA}/ca.crt" -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;')"

# Package it.
print_step "Exporting to PKCS#12..."
openssl pkcs12 \
        -export \
        -in "${CERTDIR}/${SERVER}.crt" \
        -inkey "${CERTDIR}/${SERVER}.key" \
        -certfile "${CA}/ca.crt" \
        -name "$servername" \
        -caname "$caname" \
        -out "${CERTDIR}/${SERVER}.p12"

# Verify the exported file
print_step "Verifying PKCS#12 contents..."
if ! openssl pkcs12 -in "${CERTDIR}/${SERVER}.p12" -info -noout -passin "pass:${TEST_PASSPHRASE}"; then
    print_error "Failed to verify PKCS#12 file"
fi

print_success "Server certificate exported and verified successfully"

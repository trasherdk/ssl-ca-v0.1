#!/bin/sh
##
##  user-p12.sh - Pack user certificate into PKCS#12 format
##

BASE=$(dirname $(realpath $0))
cd ${BASE}

source "${BASE}/lib/helpers.sh" || exit 1

if [ $# -ne 1 ]; then
        print_error "Usage: $0 email"
fi

EMAIL=$1
shift

CA="${BASE}/CA"
CERTDIR="${BASE}/certs/users/${EMAIL}"

if [ ! -d ${CERTDIR} ]; then
        mkdir -p ${CERTDIR} || exit 1
fi

print_step "Checking for requirements..."
[ -f  "${CERTDIR}/${EMAIL}.key" ] || { print_error "${EMAIL}.key Not found..."; }
[ -f  "${CERTDIR}/${EMAIL}.crt" ] || { print_error "${EMAIL}.crt Not found..."; }
[ -f  "${CA}/ca.crt" ] || { print_error "${CA}/ca.crt Not found..."; }

username="$(openssl x509 -noout  -in "${CERTDIR}/${EMAIL}.crt" -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;')"
caname="$(openssl x509 -noout  -in "${CA}/ca.crt" -subject | sed -e 's;.*CN=;;' -e 's;/Em.*;;')"

# Package it. An empty password is valid.
print_step "Exporting to PKCS#12..."
read_p12_export_pass
openssl pkcs12 \
        -export \
        -in "${CERTDIR}/${EMAIL}.crt" \
        -inkey "${CERTDIR}/${EMAIL}.key" \
        -certfile "${CA}/ca.crt" \
        -name "$username" \
        -caname "$caname" \
        -passout "pass:${P12_EXPORT_PASS}" \
        -out "${CERTDIR}/${EMAIL}.p12"

# Verify the exported file with the same password, including empty.
print_step "Verifying PKCS#12 contents..."
if ! openssl pkcs12 -in "${CERTDIR}/${EMAIL}.p12" -info -noout -passin "pass:${P12_EXPORT_PASS}"; then
    print_error "Failed to verify PKCS#12 file"
fi

print_success "User certificate exported and verified successfully"

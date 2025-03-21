#!/bin/bash
##
##  check-expiry.sh - Check for certificates nearing expiration and send email notifications
##

BASE=$(realpath $(dirname $0))
CA_DIR="${BASE}/CA"
SUB_CA_DIR="${BASE}/sub-CAs"
CERTS_DIR="${BASE}/certs"
EMAIL="admin@example.com" # Replace with the administrator's email address
DAYS_THRESHOLD=30         # Notify if certificates expire within this many days

# Function to check a single certificate
check_certificate() {
    local cert_path=$1
    local cert_name=$2

    if [ ! -f "${cert_path}" ]; then
        echo "Warning: Certificate ${cert_name} not found at ${cert_path}."
        return
    fi

    # Extract the expiration date and calculate days remaining
    local expiry_date=$(openssl x509 -in "${cert_path}" -noout -enddate | cut -d'=' -f2)
    local expiry_timestamp=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s)
    local current_timestamp=$(date +%s)
    local days_remaining=$(( (expiry_timestamp - current_timestamp) / 86400 ))

    # Check if the certificate is nearing expiration
    if [ "${days_remaining}" -le "${DAYS_THRESHOLD}" ]; then
        echo "Certificate ${cert_name} is expiring in ${days_remaining} days (${expiry_date})."
        echo "Certificate ${cert_name} is expiring in ${days_remaining} days (${expiry_date})." | \
            mail -s "Certificate Expiry Warning: ${cert_name}" "${EMAIL}"
    fi
}

# Check the root CA certificate
echo "Checking root CA certificate..."
check_certificate "${CA_DIR}/ca.crt" "Root CA"

# Check sub-CA certificates
if [ -d "${SUB_CA_DIR}" ]; then
    echo "Checking sub-CA certificates..."
    for sub_ca in "${SUB_CA_DIR}"/*; do
        if [ -d "${sub_ca}/CA" ]; then
            check_certificate "${sub_ca}/CA/$(basename "${sub_ca}").crt" "Sub-CA $(basename "${sub_ca}")"
        fi
    done
fi

# Check issued certificates (server and user)
echo "Checking issued certificates..."
if [ -d "${CERTS_DIR}" ]; then
    for cert in $(find "${CERTS_DIR}" -name "*.crt"); do
        cert_name=$(basename "${cert}" .crt)
        check_certificate "${cert}" "${cert_name}"
    done
fi

echo "Certificate expiry check completed."

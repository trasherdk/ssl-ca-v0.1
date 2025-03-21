#!/bin/bash
##
##  check-expiry.sh - Check for certificates nearing expiration and send email notifications
##

BASE=$(realpath $(dirname $0))
CA_DIR="${BASE}/CA"
SUB_CA_DIR="${BASE}/sub-CAs"
CERTS_DIR="${BASE}/certs"

# Check if root CA certificate and key exist
if [ ! -f "${CA_DIR}/ca.crt" ] || [ ! -f "${CA_DIR}/ca.key" ]; then
    echo "Error: Root CA certificate or key not found in ${CA_DIR}"
    exit 1
fi

# Source environment variables for default values
if [ -f "${BASE}/.env" ]; then
    source "${BASE}/.env"
fi

# Default thresholds if not set in .env
ROOT_CA_THRESHOLD=${ROOT_CA_THRESHOLD:-90}  # 90 days for root CA
SUB_CA_THRESHOLD=${SUB_CA_THRESHOLD:-60}   # 60 days for sub-CAs
CERT_THRESHOLD=${CERT_THRESHOLD:-30}       # 30 days for end-entity certificates

# Function to extract email from certificate
get_cert_email() {
    local cert_path=$1
    local email

    # Try to get email from subject alternative name
    email=$(openssl x509 -in "${cert_path}" -noout -text | grep -o 'email:.*' | cut -d':' -f2- | tr -d ' ' | head -n1)

    # If not found, try to get from subject DN
    if [ -z "${email}" ]; then
        email=$(openssl x509 -in "${cert_path}" -noout -subject -nameopt multiline | grep emailAddress | sed 's/.*=//;s/ //g')
    fi

    echo "${email}"
}

# Function to check a single certificate
check_certificate() {
    local cert_path=$1
    local cert_name=$2
    local threshold=$3

    if [ ! -f "${cert_path}" ]; then
        echo "Warning: Certificate ${cert_name} not found at ${cert_path}."
        return 1
    fi

    # Extract certificate details
    if ! openssl x509 -in "${cert_path}" -noout >/dev/null 2>&1; then
        echo "Error: Invalid certificate ${cert_name} at ${cert_path}"
        return 1
    fi

    local expiry_date=$(openssl x509 -in "${cert_path}" -noout -enddate | cut -d'=' -f2)
    local subject=$(openssl x509 -in "${cert_path}" -noout -subject | sed 's/subject= //')
    local issuer=$(openssl x509 -in "${cert_path}" -noout -issuer | sed 's/issuer= //')
    local serial=$(openssl x509 -in "${cert_path}" -noout -serial | sed 's/serial=//')

    # Calculate days remaining
    local expiry_timestamp=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s)
    local current_timestamp=$(date +%s)
    local days_remaining=$(( (expiry_timestamp - current_timestamp) / 86400 ))

    # Check if the certificate is nearing expiration
    if [ "${days_remaining}" -le "${threshold}" ]; then
        local message="Certificate Details:\n"
        message+="Name: ${cert_name}\n"
        message+="Days Remaining: ${days_remaining}\n"
        message+="Expiry Date: ${expiry_date}\n"
        message+="Subject: ${subject}\n"
        message+="Issuer: ${issuer}\n"
        message+="Serial: ${serial}\n"
        message+="Path: ${cert_path}"

        echo -e "${message}"

        # Get email from certificate or use fallback
        local cert_email=$(get_cert_email "${cert_path}")
        local notify_email=${cert_email:-${EMAIL}}

        if [ -z "${notify_email}" ]; then
            echo "Warning: No email found in certificate and no fallback email in .env"
            return 1
        fi

        # Check if mail command exists
        if command -v mail >/dev/null 2>&1; then
            echo -e "${message}" | \
                mail -s "Certificate Expiry Warning: ${cert_name} (${days_remaining} days)" "${notify_email}"
            echo "Notification sent to: ${notify_email}"
        else
            echo "Warning: 'mail' command not found. Can't send email notification."
        fi
    fi

    return 0
}

# Check the root CA certificate
echo "Checking root CA certificate..."
check_certificate "${CA_DIR}/ca.crt" "Root CA" "${ROOT_CA_THRESHOLD}"

# Check sub-CA certificates
if [ -d "${SUB_CA_DIR}" ]; then
    echo "Checking sub-CA certificates..."
    for sub_ca in "${SUB_CA_DIR}"/*; do
        if [ -d "${sub_ca}/CA" ]; then
            check_certificate "${sub_ca}/CA/$(basename "${sub_ca}").crt" "Sub-CA $(basename "${sub_ca}")" "${SUB_CA_THRESHOLD}"
        fi
    done
fi

# Check issued certificates (server and user)
echo "Checking issued certificates..."
if [ -d "${CERTS_DIR}" ]; then
    for cert in $(find "${CERTS_DIR}" -name "*.crt"); do
        cert_name=$(basename "${cert}" .crt)
        check_certificate "${cert}" "${cert_name}" "${CERT_THRESHOLD}"
    done
fi

echo "Certificate expiry check completed."

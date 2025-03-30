#!/bin/bash
##
##  check-expiry.sh - Check for certificates nearing expiration and send email notifications
##  Usage: check-expiry.sh [-f|--force] [-d|--debug] [--no-email]
##    -f, --force    Force notifications regardless of thresholds
##    -d, --debug    Enable debug output (verbose sendmail, detailed progress)
##    --no-email    Disable email notifications
##

BASE=$(realpath $(dirname $0))
CA_DIR="${BASE}/CA"
SUB_CA_DIR="${BASE}/sub-CAs"  # Operational sub-CAs
CERTS_DIR="${BASE}/certs"
SUB_CA_REGISTRY="${CERTS_DIR}/sub-CAs"  # Registry of all sub-CAs

# Process command line arguments
FORCE=false
DEBUG=false
NO_EMAIL=false
while [ $# -gt 0 ]; do
    case "$1" in
        -f|--force)
            FORCE=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        --no-email)
            NO_EMAIL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to print debug messages
debug_msg() {
    if [ "${DEBUG}" = true ]; then
        echo "[DEBUG] $1"
    fi
}

# Function to print status messages
status_msg() {
    echo "[INFO] $1"
}

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
    local current_timestamp=${CURRENT_TIMESTAMP:-$(date +%s)}  # Allow override for testing
    local days_remaining=$(( (expiry_timestamp - current_timestamp) / 86400 ))

    # Check if the certificate is nearing expiration or force is enabled
    if [ "${FORCE}" = true ] || [ "${days_remaining}" -le "${threshold}" ]; then
        local message="Certificate Details:\n"
        message+="Name: ${cert_name}\n"
        message+="Days Remaining: ${days_remaining}\n"
        message+="Expiry Date: ${expiry_date}\n"
        message+="Subject: ${subject}\n"
        message+="Issuer: ${issuer}\n"
        message+="Serial: ${serial}\n"
        message+="Path: ${cert_path}"

        debug_msg "Certificate details:\n${message}"

        # Get email from certificate and report it
        local cert_email=$(get_cert_email "${cert_path}")
        if [ -n "${cert_email}" ]; then
            debug_msg "Found email in certificate: ${cert_email}"
        fi

        # Skip email notifications if --no-email was specified
        if [ "${NO_EMAIL}" = true ]; then
            debug_msg "Email notifications disabled"
            return 0
        fi

        # Use EMAIL from .env for notifications
        if [ -z "${EMAIL}" ]; then
            echo "Warning: No EMAIL set in .env for notifications"
            return 1
        fi

        # Extract domain from email and get MX server
        local mail_domain=${EMAIL#*@}
        debug_msg "Checking MX records for domain: ${mail_domain}"
        local mx_server=$(host -t mx "${mail_domain}" | grep -m1 'mail is handled by' | awk '{print $NF}' | sed 's/\.$//')
        if [ -z "${mx_server}" ]; then
            echo "Warning: No MX records found for ${mail_domain}"
            return 1
        fi
        debug_msg "Found MX server: ${mx_server}"

        # Check if we have sendmail
        if ! command -v sendmail >/dev/null 2>&1; then
            echo "Warning: 'sendmail' command not found. Can't send email notification."
            return 1
        fi

        # Get external IP and use it for hostname lookup
        local external_ip=$(curl -s ifconfig.me)
        if [ -z "${external_ip}" ]; then
            echo "Warning: Could not determine external IP address"
            return 1
        fi
        debug_msg "External IP: ${external_ip}"
        
        # Get hostname for the IP
        local host_output=$(host "${external_ip}")
        if ! echo "${host_output}" | grep -q 'domain name pointer'; then
            echo "Warning: Could not determine hostname for IP ${external_ip}"
            return 1
        fi
        local hostname=$(echo "${host_output}" | grep -o 'domain name pointer .*' | cut -d' ' -f4 | sed 's/\.$//')
        debug_msg "Using hostname: ${hostname}"
        
        local from_address="ssl-ca@${hostname}"

        # Prepare email headers
        local date_header=$(date -R)
        local message_id="<$(date +%Y%m%d%H%M%S).$$@${hostname}>"

        # Send using sendmail with proper headers and verbose output
        local sendmail_opts="-i -f ssl-ca@${hostname} -F 'SSL CA Monitor' -S ssl-ca@${hostname} -oem -oi -om"
        # Add TLS settings
        sendmail_opts="${sendmail_opts} -oMtls=client"
        # Always use verbose mode for better debugging
        sendmail_opts="${sendmail_opts} -v"

        # Use a temporary file for sendmail output
        local sendmail_output=$(mktemp)
        if echo -e "From: SSL CA Monitor <${from_address}>\nDate: ${date_header}\nMessage-ID: ${message_id}\nTo: ${EMAIL}\nReply-To: ${from_address}\nX-Mailer: SSL CA Monitor\nX-Priority: 1\nImportance: High\nPrecedence: high\nAuto-Submitted: auto-generated\nMIME-Version: 1.0\nContent-Type: text/plain; charset=us-ascii\nSubject: Certificate Expiry Warning: ${cert_name} (${days_remaining} days)\n\n${message}" | sendmail ${sendmail_opts} "${EMAIL}" 2>${sendmail_output}; then
            status_msg "[INFO] Sent expiry notification for ${cert_name} to ${EMAIL}"
            rm -f "${sendmail_output}"
        else
            # Check if it's really a failure or just verbose output
            if grep -q "^\*\*\* Error code" "${sendmail_output}"; then
                echo "Warning: Failed to send email notification via ${mx_server}"
                cat "${sendmail_output}" >&2
            else
                status_msg "[INFO] Sent expiry notification for ${cert_name} to ${EMAIL}"
            fi
            rm -f "${sendmail_output}"
        fi
    fi

    return 0
}

# Check the root CA certificate
status_msg "Checking root CA certificate..."
check_certificate "${CA_DIR}/ca.crt" "Root CA" "${ROOT_CA_THRESHOLD}"

# Check sub-CA certificates from both operational and registry directories
status_msg "Checking sub-CA certificates..."

# 1. Check operational sub-CAs
debug_msg "Checking operational sub-CAs in ${SUB_CA_DIR}"
if [ -d "${SUB_CA_DIR}" ]; then
    for sub_ca in "${SUB_CA_DIR}"/*; do
        if [ -d "${sub_ca}/CA" ]; then
            check_certificate "${sub_ca}/CA/ca.crt" "Sub-CA $(basename "${sub_ca}") (operational)" "${SUB_CA_THRESHOLD}"
        fi
    done
fi

# 2. Check registered sub-CAs
debug_msg "Checking registered sub-CAs in ${SUB_CA_REGISTRY}"
if [ -d "${SUB_CA_REGISTRY}" ]; then
    for sub_ca in "${SUB_CA_REGISTRY}"/*; do
        if [ -d "${sub_ca}" ]; then
            sub_ca_name=$(basename "${sub_ca}")
            if [ -f "${sub_ca}/ca.crt" ]; then
                check_certificate "${sub_ca}/ca.crt" "Sub-CA ${sub_ca_name} (registered)" "${SUB_CA_THRESHOLD}"
            fi
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

status_msg "Certificate expiry check completed."

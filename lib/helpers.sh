#!/bin/bash

# Source colors
COLORS="/etc/profile.d/colors.sh"
if [ -f "$COLORS" ]; then
    source "$COLORS"
fi

# Helper functions
print_header() {
    echo -e "\n${WHITE}=== $1 ===${RESTORE}\n"
}

print_step() {
    echo -e "${CYAN}-> $1${RESTORE}"
}

print_success() {
    echo -e "${LGREEN}✓ $1${RESTORE}"
}

print_error() {
    echo -e "${RED}✗ $1${RESTORE}"
    exit 1
}

print_soft_error() {
    echo -e "${RED}✗ $1${RESTORE}"
    return 1
}

# Fill KEY_PASS_ARGS for openssl -passin or -passout.
# OPENSSL_PASSIN is passed through as-is (for example pass:secret or env:VAR).
# CA_PASSPHRASE is the raw secret. With neither set, OpenSSL prompts.
set_key_pass_args() {
    local direction="$1"
    KEY_PASS_ARGS=()
    if [ -n "${OPENSSL_PASSIN:-}" ]; then
        KEY_PASS_ARGS=("-${direction}" "${OPENSSL_PASSIN}")
    elif [ -n "${CA_PASSPHRASE:-}" ]; then
        KEY_PASS_ARGS=("-${direction}" "pass:${CA_PASSPHRASE}")
    fi
}

# CRL_URL in the signing CA's .env names that CA's list. An exported value is
# used only when the file does not set one.
load_ca_env() {
    local env_file="$1"
    local file_url=""
    if [ -f "${env_file}" ]; then
        file_url=$(awk -F= '/^[[:space:]]*CRL_URL=/{print substr($0, index($0,"=")+1); exit}' "${env_file}")
        file_url="${file_url#\"}"
        file_url="${file_url%\"}"
        file_url="${file_url#\'}"
        file_url="${file_url%\'}"
    fi
    if [ -n "${file_url}" ]; then
        CRL_URL="${file_url}"
    fi
}

require_crl_url() {
    if [ -z "${CRL_URL:-}" ]; then
        print_error "CRL_URL is not set. Add it to .env for the CA that signs this certificate."
    fi
}

# Rebuild the local CRL after a revoke. The generator lives next to this CA.
regenerate_ca_crl() {
    local base="$1"
    if [ ! -x "${base}/gen-root-ca-crl.sh" ]; then
        print_error "Cannot regenerate the CRL: ${base}/gen-root-ca-crl.sh is missing."
    fi
    "${base}/gen-root-ca-crl.sh"
}

# Revoke a certificate already present in the CA index.
# Usage: revoke_issued_cert <cert_path> <ca_dir> <openssl_config>
revoke_issued_cert() {
    local cert_path="$1"
    local ca_dir="$2"
    local config="$3"
    set_key_pass_args passin
    openssl ca -config "${config}" -revoke "${cert_path}" \
        -keyfile "${ca_dir}/ca.key" -cert "${ca_dir}/ca.crt" \
        "${KEY_PASS_ARGS[@]}"
}
# Usage: update_ca_index_type <ca_dir> <type>
# Types: server, user, subca
update_ca_index_type() {
    local ca_dir="$1"
    local cert_type="$2"
    local index_file="${ca_dir}/ca.db.index"

    if [ ! -f "$index_file" ]; then
        return 1
    fi

    # Get the last line (most recently added certificate) and update its type field (5th field)
    # The index file format is: Status Expiration RevocationDate Serial Type DN
    # We replace "unknown" with the specified type for the last line
    # Use sed to replace the 5th tab-separated field
    local last_line=$(tail -n 1 "$index_file")
    local updated_line=$(echo "$last_line" | awk -F'\t' -v type="$cert_type" 'BEGIN {OFS="\t"} { $5 = type; print }')

    # Replace the last line with the updated version
    head -n -1 "$index_file" > "${index_file}.tmp"
    echo "$updated_line" >> "${index_file}.tmp"
    mv "${index_file}.tmp" "$index_file"
}


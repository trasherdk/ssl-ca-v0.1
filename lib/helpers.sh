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

# Update the type field in the CA index file for the most recently added certificate
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


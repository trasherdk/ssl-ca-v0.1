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


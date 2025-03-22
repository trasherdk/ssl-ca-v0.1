#!/bin/bash
##
##  test-expiry.sh - Test certificate expiry notifications with force flag
##

BASE=$(realpath $(dirname $0))

# Source common test functions
source "${BASE}/scripts/test-functions.sh"

print_header "Testing Certificate Expiry Notifications"

# Run check-expiry with force flag to test notifications
print_step "Running expiry check with force flag..."
output=$("${BASE}/check-expiry.sh" --force --debug 2>&1)
echo "$output"

# Check if emails were found and notifications sent
if ! echo "$output" | grep -q "\[DEBUG\] Found email in certificate"; then
    print_error "No email addresses found in certificates"
fi

if ! echo "$output" | grep -q "\[INFO\] Sent expiry notification"; then
    print_error "No notifications were sent"
fi

print_success "Certificate expiry notifications tested successfully"

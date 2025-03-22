#!/bin/bash
##
## test-cert-chain.sh - Test the full certificate chain creation and expiry checking
##

# Test passphrase
TEST_PASSPHRASE="testpass"

# Source colors
COLORS="/etc/profile.d/colors.sh"
if [ -f "$COLORS" ]; then
    source "$COLORS"
fi

# Base directory setup
BASE=$(realpath $(dirname $0))
cd "${BASE}"

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

verify_cert() {
    local cert=$1
    local purpose=$2
    openssl verify -purpose "$purpose" -CAfile CA/ca.crt "$cert" || print_error "Certificate verification failed for $cert"
}

# Clean up existing CA structure
print_header "Cleaning up environment"
rm -rf CA sub-CAs certs config

# Test Root CA Creation
print_header "Testing Root CA Creation"
print_step "Creating Root CA..."

# Create test pipe for Root CA
test_pipe="${TEST_DIR}/test_pipe_root"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/root-ca.log" < "$test_pipe" &
TEE_PID=$!

# Run expect with visible output
expect <<EOF > "$test_pipe"
log_user 1
set timeout 60
spawn ./new-root-ca.sh
expect {
    "Enter pass phrase for" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Country Name*" {
        send "DK\r"
        exp_continue
    }
    "State or Province Name*" {
        send "Denmark\r"
        exp_continue
    }
    "Locality Name*" {
        send "Copenhagen\r"
        exp_continue
    }
    "Organization Name*" {
        send "Test Organization\r"
        exp_continue
    }
    "Organizational Unit Name*" {
        send "Test Unit\r"
        exp_continue
    }
    "Common Name*" {
        send "Test Root CA\r"
        exp_continue
    }
    "Email Address*" {
        send "test@example.com\r"
        exp_continue
    }
    timeout {
        puts "Timeout during Root CA creation"
        exit 1
    }
    eof
}
wait
EOF

# Check if Root CA was created successfully
if [ ! -f "${BASE}/CA/ca.key" ] || [ ! -f "${BASE}/CA/ca.crt" ]; then
    print_error "Root CA creation failed"
fi

# Test Sub CA Creation
print_header "Testing Sub CA Creation"
print_step "Creating Sub CA 'test-sub'..."

# Create test pipe for Sub CA
test_pipe="${TEST_DIR}/test_pipe_sub"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/sub-ca.log" < "$test_pipe" &
TEE_PID=$!

# Run expect with visible output
expect <<EOF > "$test_pipe"
log_user 1
set timeout 60
spawn ./new-sub-ca.sh test-sub
expect {
    "Enter pass phrase for" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Country Name*" {
        send "DK\r"
        exp_continue
    }
    "State or Province Name*" {
        send "Denmark\r"
        exp_continue
    }
    "Locality Name*" {
        send "Copenhagen\r"
        exp_continue
    }
    "Organization Name*" {
        send "Test Organization\r"
        exp_continue
    }
    "Organizational Unit Name*" {
        send "Test Sub CA Unit\r"
        exp_continue
    }
    "Common Name*" {
        send "Test Sub CA\r"
        exp_continue
    }
    "Email Address*" {
        send "sub-ca@example.com\r"
        exp_continue
    }
    "Sign the certificate?" {
        send "y\r"
        exp_continue
    }
    "commit?" {
        send "y\r"
        exp_continue
    }
    timeout {
        puts "Timeout during Sub CA creation"
        exit 1
    }
    eof
}
wait
EOF

# Verify Sub CA certificate
print_step "Verifying Sub CA certificate..."
verify_cert "sub-CAs/test-sub/CA/ca.crt" "crlsign"
print_success "Sub CA certificate verified"

# Test Server Certificate Creation
print_header "Testing Server Certificate Creation"
print_step "Creating server certificate..."

# Create test pipe for server cert
test_pipe="${TEST_DIR}/test_pipe_server"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/server-cert.log" < "$test_pipe" &
TEE_PID=$!

# Run expect with visible output for new-server-cert.sh
expect <<EOF > "$test_pipe"
log_user 1
set timeout 60
spawn ./new-server-cert.sh www.example.com
expect {
    "Enter pass phrase for" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Country Name*" {
        send "DK\r"
        exp_continue
    }
    "State or Province Name*" {
        send "Denmark\r"
        exp_continue
    }
    "Locality Name*" {
        send "Copenhagen\r"
        exp_continue
    }
    "Organization Name*" {
        send "Test Organization\r"
        exp_continue
    }
    "Organizational Unit Name*" {
        send "Test Server Unit\r"
        exp_continue
    }
    "Common Name*" {
        send "www.example.com\r"
        exp_continue
    }
    "Email Address*" {
        send "server@example.com\r"
        exp_continue
    }
    timeout {
        puts "Timeout during server certificate creation"
        exit 1
    }
    eof
}
wait
EOF

# Now sign the server certificate
print_step "Signing server certificate..."

# Create test pipe for signing
test_pipe="${TEST_DIR}/test_pipe_server_sign"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/server-cert-sign.log" < "$test_pipe" &
TEE_PID=$!

# Run expect with visible output for sign-server-cert.sh
expect <<EOF > "$test_pipe"
log_user 1
set timeout 60
spawn ./sign-server-cert.sh www.example.com
expect {
    "Enter pass phrase for" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Sign the certificate?" {
        send "y\r"
        exp_continue
    }
    "commit?" {
        send "y\r"
        exp_continue
    }
    timeout {
        puts "Timeout during server certificate signing"
        exit 1
    }
    eof
}
wait
EOF

# Verify server certificate
print_step "Verifying server certificate..."
verify_cert "certs/www.example.com/www.example.com.crt" "sslserver"
print_success "Server certificate verified"

# Test User Certificate Creation
print_header "Testing User Certificate Creation"
print_step "Creating user certificate..."

# Create test pipe for user cert
test_pipe="${TEST_DIR}/test_pipe_user"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/user-cert.log" < "$test_pipe" &
TEE_PID=$!

# Run expect with visible output
expect <<EOF > "$test_pipe"
log_user 1
set timeout 60
spawn ./new-user-cert.sh user@example.com
expect {
    "Enter pass phrase for" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Country Name*" {
        send "DK\r"
        exp_continue
    }
    "State or Province Name*" {
        send "Denmark\r"
        exp_continue
    }
    "Locality Name*" {
        send "Copenhagen\r"
        exp_continue
    }
    "Organization Name*" {
        send "Test Organization\r"
        exp_continue
    }
    "Organizational Unit Name*" {
        send "Test User Unit\r"
        exp_continue
    }
    "Common Name*" {
        send "Test User\r"
        exp_continue
    }
    "Email Address*" {
        send "user@example.com\r"
        exp_continue
    }
    "Sign the certificate?" {
        send "y\r"
        exp_continue
    }
    "commit?" {
        send "y\r"
        exp_continue
    }
    timeout {
        puts "Timeout during user certificate creation"
        exit 1
    }
    eof
}
wait
EOF

# Sign the user certificate
print_step "Signing user certificate..."

# Create test pipe for signing
test_pipe="${TEST_DIR}/test_pipe_user_sign"
mkfifo "$test_pipe"

# Start logging in background
tee "${TEST_DIR}/user-cert-sign.log" < "$test_pipe" &
TEE_PID=$!

# Run expect with visible output for sign-user-cert.sh
expect <<EOF > "$test_pipe"
log_user 1
set timeout 60
spawn ./sign-user-cert.sh user@example.com
expect {
    "Enter pass phrase for" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Sign the certificate?" {
        send "y\r"
        exp_continue
    }
    "commit?" {
        send "y\r"
        exp_continue
    }
    timeout {
        puts "Timeout during user certificate signing"
        exit 1
    }
    eof
}
wait
EOF

# Verify user certificate
print_step "Verifying user certificate..."
verify_cert "certs/users/user@example.com/user@example.com.crt" "sslclient"
print_success "User certificate verified"

# Test Certificate Expiry
print_header "Testing Certificate Expiry"

print_step "Displaying actual expiry dates..."
echo "Root CA: $(openssl x509 -enddate -noout -in CA/ca.crt)"
echo "Sub CA: $(openssl x509 -enddate -noout -in sub-CAs/test-sub/CA/ca.crt)"
echo "Server cert: $(openssl x509 -enddate -noout -in certs/www.example.com/www.example.com.crt)"
echo "User cert: $(openssl x509 -enddate -noout -in certs/users/user@example.com/user@example.com.crt)"

print_step "Testing with 1-day threshold (should not warn)..."
# Temporarily override thresholds but preserve other settings
cp .env .env.bak
sed -i 's/^ROOT_CA_THRESHOLD=.*/ROOT_CA_THRESHOLD=1/' .env
sed -i 's/^SUB_CA_THRESHOLD=.*/SUB_CA_THRESHOLD=1/' .env
sed -i 's/^CERT_THRESHOLD=.*/CERT_THRESHOLD=1/' .env

output=$(./check-expiry.sh 2>&1)
if echo "$output" | grep -q "Days Remaining"; then
    print_error "Got unexpected expiry warning with 1-day threshold"
fi
print_success "No warnings with 1-day threshold"

print_step "Testing with configured thresholds..."
# Restore original .env
mv .env.bak .env
output=$(./check-expiry.sh 2>&1)
if ! echo "$output" | grep -q "Days Remaining"; then
    print_error "Expected expiry warning"
fi
print_success "Got expected warnings"

print_step "Testing email extraction..."
if ! echo "$output" | grep -q "Found email in certificate"; then
    print_error "No email found in certificates"
fi
print_success "Found emails in certificates"

print_step "Testing notification email..."
if ! echo "$output" | grep -q "Sending notification"; then
    print_error "Notification not being sent"
fi
print_success "Notifications being sent"

print_header "Test Summary"
print_success "All certificate chain and expiry tests passed successfully!"

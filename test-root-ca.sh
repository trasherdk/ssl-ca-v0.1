#!/bin/bash
##
## test-root-ca.sh - Test Root CA creation and operations
##

# Source colors
COLORS="/etc/profile.d/colors.sh"
if [ -f "$COLORS" ]; then
    source "$COLORS"
fi

# Base directory and test environment setup
BASE=$(realpath $(dirname $0))
TEST_DIR="${BASE}/test-environment"
TEST_PASSPHRASE="testpass"

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

# Setup test environment
print_header "Setting up test environment"
print_step "Creating test directory..."
rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# Create named pipe for logging while showing output
test_pipe="${TEST_DIR}/test_pipe"
mkfifo "$test_pipe"

# Test Root CA Creation
print_header "Testing Root CA Creation"

print_step "Creating Root CA..."
# Start logging in background
tee "${TEST_DIR}/root-ca.log" < "$test_pipe" &
TEE_PID=$!

# Run expect with visible output
expect <<EOF > "$test_pipe"
log_user 1
spawn "${BASE}/new-root-ca.sh"
expect {
    "Enter PEM pass phrase:" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Verifying - Enter PEM pass phrase:" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
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
        puts "\n${RED}Timeout waiting for prompt${RESTORE}"
        exit 1
    }
    eof
}
EOF
RESULT=$?

# Clean up the pipe and background process
wait $TEE_PID
rm "$test_pipe"

# Verify Root CA creation
if [ $RESULT -ne 0 ]; then
    print_error "Root CA creation failed with exit code $RESULT"
fi

if [ ! -f "${BASE}/CA/ca.crt" ]; then
    print_error "Root CA certificate not found. Check ${TEST_DIR}/root-ca.log for details."
fi

print_success "Root CA created successfully"

# Verify Root CA certificate and infrastructure
print_step "Verifying Root CA setup..."

# Check file permissions
print_step "Checking file permissions..."
if [ $(stat -c %a "${BASE}/CA/ca.key") != "600" ]; then
    print_error "Root CA private key has incorrect permissions. Expected 600"
fi

if [ $(stat -c %a "${BASE}/CA/ca.crt") != "644" ]; then
    print_error "Root CA certificate has incorrect permissions. Expected 644"
fi

print_success "File permissions are correct"

# Verify certificate structure
print_step "Verifying certificate structure..."
openssl x509 -in "${BASE}/CA/ca.crt" -text -noout > "${TEST_DIR}/ca-verify.log" 2>&1
if [ $? -ne 0 ]; then
    print_error "Root CA certificate verification failed. Check ${TEST_DIR}/ca-verify.log for details."
fi

# Check certificate contents
CERT_TEXT=$(openssl x509 -in "${BASE}/CA/ca.crt" -text -noout)

# Check basic constraints
if ! echo "$CERT_TEXT" | grep -q "CA:TRUE"; then
    print_error "Root CA certificate missing CA:TRUE basic constraint"
fi

# Verify key usage
if ! echo "$CERT_TEXT" | grep -q "Certificate Sign"; then
    print_error "Root CA certificate missing Certificate Sign key usage"
fi
if ! echo "$CERT_TEXT" | grep -q "CRL Sign"; then
    print_error "Root CA certificate missing CRL Sign key usage"
fi

# Verify certificate fields
if ! echo "$CERT_TEXT" | grep -q "Issuer: C = DK, ST = Denmark, L = Copenhagen, O = Test Organization, OU = Test Unit, CN = Test Root CA"; then
    print_error "Root CA certificate has incorrect issuer fields"
fi

# Verify key size
if ! echo "$CERT_TEXT" | grep -q "Public-Key: (4096 bit)"; then
    print_error "Root CA certificate does not use 4096-bit key"
fi

# Check CA database initialization
print_step "Checking CA database initialization..."
if [ ! -f "${BASE}/CA/ca.db.serial" ]; then
    print_error "Serial number file not initialized"
fi
if [ ! -f "${BASE}/CA/ca.db.index" ]; then
    print_error "Index database not initialized"
fi
if [ ! -d "${BASE}/CA/ca.db.certs" ]; then
    print_error "Certificate storage directory not initialized"
fi

# Verify serial number format
SERIAL=$(cat "${BASE}/CA/ca.db.serial")
if ! [[ $SERIAL =~ ^[0-9A-F]{2}$ ]]; then
    print_error "Invalid serial number format"
fi

# Verify private key matches certificate
print_step "Verifying key pair consistency..."
CERT_MODULUS=$(openssl x509 -in "${BASE}/CA/ca.crt" -modulus -noout)
KEY_MODULUS=$(openssl rsa -in "${BASE}/CA/ca.key" -passin "pass:${TEST_PASSPHRASE}" -modulus -noout)
if [ "$CERT_MODULUS" != "$KEY_MODULUS" ]; then
    print_error "Certificate public key does not match private key"
fi

print_success "Root CA certificate and infrastructure verified successfully"

print_header "Test Summary"
echo -e "${GREEN}All Root CA tests passed successfully!${RESTORE}"

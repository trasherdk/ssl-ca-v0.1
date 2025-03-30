#!/bin/bash
##
## test-sub-ca.sh - Test Sub-CA creation and operations
##

# Base directory and test environment setup
BASE=$(realpath $(dirname $0))
TEST_DIR="${BASE}/test-environment"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1

print_header "Testing Sub-CA creation and operations"

# Test both types of Sub-CAs
SUB_CA_NORMAL="test-sub-ca-normal"
SUB_CA_RESTRICTED="test-sub-ca-restricted"

# Cleanup subdirectories
#rm -rf "${BASE}/sub-CAs/${SUB_CA_NORMAL}"
#rm -rf "${BASE}/sub-CAs/${SUB_CA_RESTRICTED}"


# Function to test a Sub-CA
test_sub_ca() {
    local SUB_CA_NAME=$1
    local NO_SUB_CA=$2
    local SUB_CA_DIR="${BASE}/sub-CAs/${SUB_CA_NAME}"
    local SUB_CA_TYPE="normal"
    if [ "$NO_SUB_CA" = "no-sub-ca" ]; then
        SUB_CA_TYPE="restricted"
    fi

    print_header "Testing ${SUB_CA_TYPE} Sub-CA Creation"

    # Ensure the test-environment directory exists before creating the FIFO file
    if [ ! -d "${TEST_DIR}" ]; then 
        mkdir -p "${TEST_DIR}"
    fi

    # Create test pipe
    test_pipe="${TEST_DIR}/test_pipe_${SUB_CA_NAME}"
    mkfifo "$test_pipe"

    print_step "Creating ${SUB_CA_TYPE} Sub-CA..."
    rm -rf "${SUB_CA_DIR}"
    # Start logging in background
    tee "${TEST_DIR}/${SUB_CA_NAME}.log" < "$test_pipe" &
    TEE_PID=$!

    # Use a wrapper to capture the exit code of new-sub-ca.sh
    expect <<EOF >> "${test_pipe}"
log_user 1
set timeout 60
spawn "${BASE}/new-sub-ca.sh" "${SUB_CA_NAME}" "${NO_SUB_CA}"
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
        send "${SUB_CA_TYPE} Sub CA Unit\r"
        exp_continue
    }
    "Common Name*" {
        send "${SUB_CA_TYPE} Sub CA\r"
        exp_continue
    }
    "Email Address*" {
        send "${SUB_CA_TYPE}-sub-ca@example.com\r"
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
    "Error: Sub-CA certificate validation failed" {
        puts "\nSub-CA certificate validation failed"
        exit 1
    }
    timeout {
        puts "\n${RED}Timeout waiting for prompt${RESTORE}"
        exit 1
    }
    eof
}
EOF
RESULT=$?

if [ $RESULT -ne 0 ]; then
    print_error "new-sub-ca.sh failed. Aborting test."
    exit 1
else
    print_success "Sub-CA creation script executed successfully: ${RESULT}"
fi

# Clean up the pipe and background process
wait $TEE_PID
rm "$test_pipe"

# Verify Sub-CA creation
if [ ! -f "${BASE}/sub-CAs/${SUB_CA_NAME}/CA/ca.crt" ]; then
    print_error "Sub-CA certificate not found at ${BASE}/sub-CAs/${SUB_CA_NAME}/CA/ca.crt"
fi

print_success "Sub-CA created successfully"

# Verify Sub-CA certificate and infrastructure
print_header "Verifying Sub-CA Setup"

# Check file permissions and ownership
print_step "Checking file permissions and ownership..."

# Check private key
KEY_PERMS=$(stat -c %a "${SUB_CA_DIR}/CA/ca.key")
KEY_OWNER=$(stat -c %U "${SUB_CA_DIR}/CA/ca.key")
if [ "$KEY_PERMS" != "600" ]; then
    print_error "Sub-CA private key has incorrect permissions. Expected 600, got ${KEY_PERMS}"
fi
if [ "$KEY_OWNER" != "root" ]; then
    print_error "Sub-CA private key has incorrect owner. Expected root, got ${KEY_OWNER}"
fi

# Check certificate
CERT_PERMS=$(stat -c %a "${SUB_CA_DIR}/CA/ca.crt")
CERT_OWNER=$(stat -c %U "${SUB_CA_DIR}/CA/ca.crt")
if [ "$CERT_PERMS" != "644" ]; then
    print_error "Sub-CA certificate has incorrect permissions. Expected 644, got ${CERT_PERMS}"
fi
if [ "$CERT_OWNER" != "root" ]; then
    print_error "Sub-CA certificate has incorrect owner. Expected root, got ${CERT_OWNER}"
fi

# Check CA database files
DB_INDEX_PERMS=$(stat -c %a "${SUB_CA_DIR}/CA/ca.db.index")
if [ "$DB_INDEX_PERMS" != "600" ]; then
    print_error "CA database index has incorrect permissions. Expected 600, got ${DB_INDEX_PERMS}"
fi

DB_SERIAL_PERMS=$(stat -c %a "${SUB_CA_DIR}/CA/ca.db.serial")
if [ "$DB_SERIAL_PERMS" != "600" ]; then
    print_error "CA database serial has incorrect permissions. Expected 600, got ${DB_SERIAL_PERMS}"
fi

print_success "File permissions and ownership are correct"

# Verify certificate structure
print_step "Verifying certificate structure..."
openssl x509 -in "${SUB_CA_DIR}/CA/ca.crt" -text -noout > "${TEST_DIR}/sub-ca-verify.log" 2>&1
if [ $? -ne 0 ]; then
    print_error "Sub-CA certificate verification failed. Check ${TEST_DIR}/sub-ca-verify.log for details."
fi

# Check certificate contents
print_step "Verifying certificate contents..."
CERT_TEXT=$(openssl x509 -in "${SUB_CA_DIR}/CA/ca.crt" -text -noout)

    # Check CA constraints based on mode
    if [ "$NO_SUB_CA" = "no-sub-ca" ]; then
        if ! echo "$CERT_TEXT" | grep -q "CA:TRUE"; then
            print_error "${SUB_CA_TYPE} Sub-CA certificate should have CA:TRUE"
        fi
        if ! echo "$CERT_TEXT" | grep -q "pathlen:0"; then
            print_error "${SUB_CA_TYPE} Sub-CA certificate should have pathlen:0 constraint"
        fi
        # Check key usage for restricted Sub-CA
        if ! echo "$CERT_TEXT" | grep -q "Certificate Sign"; then
            print_error "${SUB_CA_TYPE} Sub-CA certificate missing Certificate Sign key usage"
        fi
        if ! echo "$CERT_TEXT" | grep -q "CRL Sign"; then
            print_error "${SUB_CA_TYPE} Sub-CA certificate missing CRL Sign key usage"
        fi
    else
        if ! echo "$CERT_TEXT" | grep -q "CA:TRUE"; then
            print_error "${SUB_CA_TYPE} Sub-CA certificate missing CA:TRUE basic constraint"
        fi
        if echo "$CERT_TEXT" | grep -q "pathlen"; then
            print_error "${SUB_CA_TYPE} Sub-CA should not have a pathlen constraint"
        fi
        # Check key usage for normal Sub-CA
        if ! echo "$CERT_TEXT" | grep -q "Certificate Sign"; then
            print_error "${SUB_CA_TYPE} Sub-CA certificate missing Certificate Sign key usage"
        fi
        if ! echo "$CERT_TEXT" | grep -q "CRL Sign"; then
            print_error "${SUB_CA_TYPE} Sub-CA certificate missing CRL Sign key usage"
        fi
    fi

# Verify critical extensions
if ! echo "$CERT_TEXT" | grep -q "X509v3 Basic Constraints: critical"; then
    print_error "Basic Constraints extension is not marked as critical"
fi
if ! echo "$CERT_TEXT" | grep -q "X509v3 Key Usage: critical"; then
    print_error "Key Usage extension is not marked as critical"
fi

print_success "Certificate contents verified"

# Verify private key matches certificate
print_step "Verifying key pair consistency..."
CERT_MODULUS=$(openssl x509 -in "${SUB_CA_DIR}/CA/ca.crt" -modulus -noout)
KEY_MODULUS=$(openssl rsa -in "${SUB_CA_DIR}/CA/ca.key" -modulus -noout -passin "pass:${TEST_PASSPHRASE}")
if [ "$CERT_MODULUS" != "$KEY_MODULUS" ]; then
    print_error "Certificate public key does not match private key"
fi

print_success "Key pair consistency verified"

# Verify certificate chain
print_step "Verifying certificate chain..."
# Update the test to validate the actual CA/ca.crt file directly
openssl verify -CAfile "${SUB_CA_DIR}/CA/ca.crt" "${SUB_CA_DIR}/CA/ca.crt" > "${TEST_DIR}/chain-verify.log" 2>&1
if [ $? -ne 0 ]; then
    print_error "Certificate chain verification failed. Check ${TEST_DIR}/chain-verify.log for details."
fi

# Check CA database initialization
print_step "Checking CA database initialization..."
if [ ! -f "${SUB_CA_DIR}/CA/ca.db.serial" ]; then
    print_error "Serial number file not initialized"
fi
if [ ! -f "${SUB_CA_DIR}/CA/ca.db.index" ]; then
    print_error "Index database not initialized"
fi
if [ ! -d "${SUB_CA_DIR}/CA/ca.db.certs" ]; then
    print_error "Certificate storage directory not initialized"
fi

# Verify serial number format
SERIAL=$(cat "${SUB_CA_DIR}/CA/ca.db.serial")
if ! [[ $SERIAL =~ ^[0-9A-F]{2}$ ]]; then
    print_error "Invalid serial number format"
fi

# Verify required scripts are copied and have correct permissions
print_step "Checking required scripts..."
REQUIRED_SCRIPTS=(
    "new-server-cert.sh"
    "sign-server-cert.sh"
    "new-user-cert.sh"
    "sign-user-cert.sh"
    "revoke-cert.sh"
    "server-p12.sh"
    "user-p12.sh"
)
for script in "${REQUIRED_SCRIPTS[@]}"; do
    SCRIPT_PATH="${SUB_CA_DIR}/${script}"
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_error "Required script ${script} not found in Sub-CA directory"
    fi
    if [ ! -x "$SCRIPT_PATH" ]; then
        print_error "Required script ${script} is not executable"
    fi
    
    # Check script permissions (should be 755 or 750)
    SCRIPT_PERMS=$(stat -c %a "$SCRIPT_PATH")
    if [[ "$SCRIPT_PERMS" != "755" && "$SCRIPT_PERMS" != "750" ]]; then
        print_error "Script ${script} has incorrect permissions. Expected 755 or 750, got ${SCRIPT_PERMS}"
    fi
    
    # Check script ownership
    SCRIPT_OWNER=$(stat -c %U "$SCRIPT_PATH")
    if [ "$SCRIPT_OWNER" != "root" ]; then
        print_error "Script ${script} has incorrect owner. Expected root, got ${SCRIPT_OWNER}"
    fi
done

# Check directory permissions
for dir in "${SUB_CA_DIR}/CA" "${SUB_CA_DIR}/certs" "${SUB_CA_DIR}/config" "${SUB_CA_DIR}/crl"; do
    DIR_PERMS=$(stat -c %a "$dir")
    if [ "$DIR_PERMS" != "700" ]; then
        print_error "Directory $dir has incorrect permissions. Expected 700, got ${DIR_PERMS}"
    fi
    
    DIR_OWNER=$(stat -c %U "$dir")
    if [ "$DIR_OWNER" != "root" ]; then
        print_error "Directory $dir has incorrect owner. Expected root, got ${DIR_OWNER}"
    fi
done

print_success "All required scripts and directories have correct permissions"

    print_header "${SUB_CA_TYPE} Sub-CA Test Summary"
    echo -e "${GREEN}All ${SUB_CA_TYPE} Sub-CA tests passed successfully!${RESTORE}"
}

# Function to verify registry structure for a sub-CA
verify_registry() {
    local SUB_CA_NAME=$1
    local SUB_CA_DIR="${BASE}/sub-CAs/${SUB_CA_NAME}"
    local REGISTRY_DIR="${BASE}/certs/sub-CAs/${SUB_CA_NAME}/${SUB_CA_NAME}"

    print_step "Verifying registry for ${SUB_CA_NAME}..."

    # Check operational directory
    if [ ! -d "${SUB_CA_DIR}/CA" ]; then
        print_error "Operational directory for ${SUB_CA_NAME} not found"
    fi
    if [ ! -f "${SUB_CA_DIR}/CA/ca.crt" ]; then
        print_error "Certificate for ${SUB_CA_NAME} not found in operational directory"
    fi

    # Check registry directory
    if [ ! -d "${REGISTRY_DIR}" ]; then
        print_error "Registry directory for ${SUB_CA_NAME} not found"
    fi
    if [ ! -f "${REGISTRY_DIR}/ca.crt" ]; then
        print_error "Certificate for ${SUB_CA_NAME} not found in registry"
    fi

    # Check registry permissions
    local perms=$(stat -c "%a" "${REGISTRY_DIR}")
    if [ "${perms}" != "700" ]; then
        print_error "Incorrect permissions on ${REGISTRY_DIR}: ${perms} (should be 700)"
    fi
}

# Test normal Sub-CA (can create other CAs)
test_sub_ca "$SUB_CA_NORMAL" "no"
verify_registry "$SUB_CA_NORMAL"

# Test restricted Sub-CA (cannot create other CAs)
test_sub_ca "$SUB_CA_RESTRICTED" "no-sub-ca"
verify_registry "$SUB_CA_RESTRICTED"

print_header "Overall Test Summary"
echo -e "${GREEN}All Sub-CA tests passed successfully!${RESTORE}"

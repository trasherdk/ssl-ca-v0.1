#!/bin/bash
##
## test-check-expiry.sh - Unit tests for check-expiry.sh
##

# Setup test environment
BASE=$(realpath $(dirname $0))
TEST_DIR="${BASE}/test-environment/expiry-tests"
rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# Source common test functions
source "${BASE}/scripts/test-functions.sh"

# Setup CA environment for testing
setup_test_ca() {
    local ca_dir=$1
    
    # Copy scripts to test directory
    cp "${BASE}"/*.sh "${ca_dir}/"
    
    cd "${ca_dir}"
    
    # Create a basic CA structure
    ./new-root-ca.sh
    ./new-sub-ca.sh test-sub
    ./new-server-cert.sh test-server test@example.com
    ./new-user-cert.sh test-user user@example.com

    # Display actual expiry dates for reference
    echo "Actual certificate expiry dates:"
    echo "Root CA: $(openssl x509 -enddate -noout -in CA/ca.crt)"
    echo "Sub CA: $(openssl x509 -enddate -noout -in sub-CAs/test-sub/CA/ca.crt)"
    echo "Server cert: $(openssl x509 -enddate -noout -in certs/test-server.crt)"
    echo "User cert: $(openssl x509 -enddate -noout -in certs/test-user.crt)"
}

# Test cases
test_expiry_calculation() {
    echo "Testing expiry calculation..."
    
    # Create test CA
    local test_ca="${TEST_DIR}/expiry-test"
    mkdir -p "${test_ca}"
    setup_test_ca "${test_ca}"
    
    cd "${test_ca}"
    
    # Test with different thresholds
    # First get actual expiry dates
    root_expiry=$(openssl x509 -enddate -noout -in CA/ca.crt | cut -d= -f2)
    sub_expiry=$(openssl x509 -enddate -noout -in sub-CAs/test-sub/CA/ca.crt | cut -d= -f2)
    server_expiry=$(openssl x509 -enddate -noout -in certs/test-server.crt | cut -d= -f2)
    
    echo "Certificate expiry dates:"
    echo "Root CA expires: ${root_expiry}"
    echo "Sub CA expires: ${sub_expiry}"
    echo "Server cert expires: ${server_expiry}"
    
    # Test with 1-day threshold (should not warn)
    echo "ROOT_CA_THRESHOLD=1" > .env
    echo "SUB_CA_THRESHOLD=1" >> .env
    echo "CERT_THRESHOLD=1" >> .env
    
    output=$(./check-expiry.sh 2>&1)
    assert_not_contains "${output}" "will expire" "Should not warn with 1-day threshold"
    
    # Test with very high threshold (should warn)
    echo "ROOT_CA_THRESHOLD=3650" > .env  # 10 years
    echo "SUB_CA_THRESHOLD=3650" >> .env
    echo "CERT_THRESHOLD=3650" >> .env
    
    output=$(./check-expiry.sh 2>&1)
    assert_contains "${output}" "will expire" "Should warn with 10-year threshold"
    
    echo "✓ Expiry calculation tests passed"
}

test_email_extraction() {
    echo "Testing email extraction..."
    
    # Create test CA
    local test_ca="${TEST_DIR}/email-test"
    mkdir -p "${test_ca}"
    setup_test_ca "${test_ca}"
    
    cd "${test_ca}"
    
    # Set high threshold to ensure warnings
    echo "ROOT_CA_THRESHOLD=3650" > .env
    
    # Test email extraction from certificates
    output=$(./check-expiry.sh 2>&1)
    assert_contains "${output}" "test@example.com" "Should extract email from server cert"
    assert_contains "${output}" "user@example.com" "Should extract email from user cert"
    
    # Test fallback email when certificate is missing
    echo "EMAIL=fallback@example.com" > .env
    mv certs/test-server.crt certs/test-server.crt.bak
    output=$(./check-expiry.sh 2>&1)
    assert_contains "${output}" "fallback@example.com" "Should use fallback email when cert missing"
    mv certs/test-server.crt.bak certs/test-server.crt
    
    echo "✓ Email extraction tests passed"
}

test_threshold_config() {
    echo "Testing threshold configuration..."
    
    # Create test CA
    local test_ca="${TEST_DIR}/threshold-test"
    mkdir -p "${test_ca}"
    setup_test_ca "${test_ca}"
    
    cd "${test_ca}"
    
    # Test default thresholds
    output=$(./check-expiry.sh 2>&1)
    echo "Using default thresholds: ROOT_CA_THRESHOLD=90, SUB_CA_THRESHOLD=60, CERT_THRESHOLD=30"
    echo "Actual expiry warnings:"
    echo "${output}" | grep "will expire"
    
    # Test custom thresholds
    echo "ROOT_CA_THRESHOLD=1" > .env
    echo "SUB_CA_THRESHOLD=1" >> .env
    echo "CERT_THRESHOLD=1" >> .env
    
    output=$(./check-expiry.sh 2>&1)
    assert_not_contains "${output}" "will expire" "Should not warn with 1-day threshold"
    
    # Test very high thresholds
    echo "ROOT_CA_THRESHOLD=3650" > .env
    echo "SUB_CA_THRESHOLD=3650" >> .env
    echo "CERT_THRESHOLD=3650" >> .env
    
    output=$(./check-expiry.sh 2>&1)
    assert_contains "${output}" "will expire" "Should warn with 10-year threshold"
    
    echo "✓ Threshold configuration tests passed"
}

test_error_handling() {
    echo "Testing error handling..."
    
    # Create test CA
    local test_ca="${TEST_DIR}/error-test"
    mkdir -p "${test_ca}"
    setup_test_ca "${test_ca}"
    
    cd "${test_ca}"
    
    # Test missing root CA
    mv CA/ca.crt CA/ca.crt.bak
    output=$(./check-expiry.sh 2>&1)
    assert_contains "${output}" "Error" "Should handle missing root CA"
    mv CA/ca.crt.bak CA/ca.crt
    
    # Test invalid certificate
    cp CA/ca.crt CA/ca.crt.bak
    echo "invalid" > CA/ca.crt
    output=$(./check-expiry.sh 2>&1)
    assert_contains "${output}" "Error" "Should handle invalid certificate"
    mv CA/ca.crt.bak CA/ca.crt
    
    echo "✓ Error handling tests passed"
}

# Clean up function
cleanup() {
    rm -rf "${TEST_DIR}"
}

# Run tests
echo "Running check-expiry.sh tests..."
trap cleanup EXIT

test_expiry_calculation
test_email_extraction
test_threshold_config
test_error_handling

echo "All tests completed successfully!"

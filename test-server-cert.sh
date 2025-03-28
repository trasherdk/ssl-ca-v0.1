#!/bin/bash
##
## test-server-cert.sh - Test Server Certificate creation and signing
##

BASE=$(realpath $(dirname $0))
TEST_DIR="${BASE}/test-environment"
SERVER_NAME="test-server.com"
TEST_PASSPHRASE="testpass"

# Cleanup previous test environment
echo "Cleaning up previous test environment..."
rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# Test Server Certificate creation
echo "Testing Server Certificate creation..."
# Add debugging output to the expect script for Server Certificate creation
expect <<EOF > "${TEST_DIR}/server-cert.log" 2>&1
log_user 1
spawn "${BASE}/new-server-cert.sh" "${SERVER_NAME}"
expect {
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
        send "Server Certificates\r"
        exp_continue
    }
    "Common Name*" {
        send "test-server.com\r"
        exp_continue
    }
    "Email Address*" {
        send "hostmaster@fumlersoft.dk\r"
        exp_continue
    }
    timeout {
        puts "\nTimeout waiting for prompt"
        exit 1
    }
    eof
}
EOF
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.csr" ]; then
    echo "Server certificate creation failed. Check ${TEST_DIR}/server-cert.log for details."
    exit 1
fi
echo "Server certificate creation successful."

# Test Server Certificate signing
echo "Testing Server Certificate signing..."
expect <<EOF >> "${TEST_DIR}/server-cert.log" 2>&1
spawn "${BASE}/sign-server-cert.sh" "${SERVER_NAME}"
expect "Enter PEM pass phrase:"
send "${TEST_PASSPHRASE}\r"
expect "Sign the certificate*"
send "y\r"
expect "1 out of 1 certificate requests certified*"
send "y\r"
expect eof
EOF
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" ]; then
    echo "Server certificate signing failed. Check ${TEST_DIR}/server-cert.log for details."
    exit 1
fi
echo "Server certificate signing successful."

# Verify Server Certificate structure
echo "Verifying Server Certificate structure..."
openssl x509 -in "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" -text -noout > "${TEST_DIR}/server-cert-verify.log" 2>&1
if [ $? -ne 0 ]; then
    echo "Server certificate verification failed. Check ${TEST_DIR}/server-cert-verify.log for details."
    exit 1
fi
echo "Server certificate structure verified successfully."

# Verify Server Certificate chain
echo "Verifying Server Certificate chain..."
openssl verify -CAfile "${BASE}/CA/ca.crt" "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" > "${TEST_DIR}/server-cert-chain.log" 2>&1
if [ $? -ne 0 ]; then
    echo "Server certificate chain verification failed. Check ${TEST_DIR}/server-cert-chain.log for details."
    exit 1
fi
echo "Server certificate chain verified successfully."

echo "All Server Certificate tests passed successfully."
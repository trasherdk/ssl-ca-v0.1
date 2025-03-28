#!/bin/bash
##
## test-user-cert.sh - Test User Certificate creation and signing
##

BASE=$(realpath $(dirname $0))
TEST_DIR="${BASE}/test-environment"
USER_EMAIL="test-user@example.com"
TEST_PASSPHRASE="testpass"

# Cleanup previous test environment
echo "Cleaning up previous test environment..."
rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# Test User Certificate creation
echo "Testing User Certificate creation..."
# Add debugging output to the expect script for User Certificate creation
expect <<EOF > "${TEST_DIR}/user-cert.log" 2>&1
log_user 1
spawn "${BASE}/new-user-cert.sh" "${USER_EMAIL}"
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
        send "User Certificates\r"
        exp_continue
    }
    "Common Name*" {
        send "${USER_EMAIL}\r"
        exp_continue
    }
    "Email Address*" {
        send "${USER_EMAIL}\r"
        exp_continue
    }
    timeout {
        puts "\nTimeout waiting for prompt"
        exit 1
    }
    eof
}
EOF

echo "User certificate creation successful."

# Check if the user certificate signing request (CSR) was created successfully
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.csr" ]; then
    echo "User certificate creation failed. Check ${TEST_DIR}/user-cert.log for details."
    exit 1
fi

# Test User Certificate signing
echo "Testing User Certificate signing..."
expect <<EOF >> "${TEST_DIR}/user-cert.log" 2>&1
spawn "${BASE}/sign-user-cert.sh" "${USER_EMAIL}"
expect "Enter PEM pass phrase:"
send "${TEST_PASSPHRASE}\r"
expect "Sign the certificate*"
send "y\r"
expect "1 out of 1 certificate requests certified*"
send "y\r"
expect eof
EOF
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" ]; then
    echo "User certificate signing failed. Check ${TEST_DIR}/user-cert.log for details."
    exit 1
fi
echo "User certificate signing successful."

# Verify User Certificate structure
echo "Verifying User Certificate structure..."
openssl x509 -in "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" -text -noout > "${TEST_DIR}/user-cert-verify.log" 2>&1
if [ $? -ne 0 ]; then
    echo "User certificate verification failed. Check ${TEST_DIR}/user-cert-verify.log for details."
    exit 1
fi
echo "User certificate structure verified successfully."

# Verify User Certificate chain
echo "Verifying User Certificate chain..."
openssl verify -CAfile "${BASE}/CA/ca.crt" "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" > "${TEST_DIR}/user-cert-chain.log" 2>&1
if [ $? -ne 0 ]; then
    echo "User certificate chain verification failed. Check ${TEST_DIR}/user-cert-chain.log for details."
    exit 1
fi
echo "User certificate chain verified successfully."

echo "All User Certificate tests passed successfully."
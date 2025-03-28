#!/bin/bash
##
## test-ca-setup.sh - Automated testing for the CA setup with password handling
##

# Dynamically detect the working directory as the root
if [[ $(basename $(realpath $(dirname $0))) == "test" ]]; then
    BASE=$(realpath $(dirname $0)/..)
else
    BASE=$(realpath $(dirname $0))
fi

TEST_DIR="${BASE}/test-environment"
ROOT_CA_DIR="${TEST_DIR}/CA"
SUB_CA_NAME="test-sub-ca"
SERVER_NAME="test-server.com"
USER_EMAIL="test-user@example.com"
TEST_PASSPHRASE="testpass"

# Cleanup previous test environment
echo "Cleaning up previous test environment..."
rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# Test Root CA creation
echo "Testing Root CA creation..."
# Add debugging output to the expect script for Root CA creation
expect <<EOF > "${TEST_DIR}/root-ca.log" 2>&1
log_user 1
spawn "${BASE}/new-root-ca.sh"
expect "Enter PEM pass phrase:"
send -- "${TEST_PASSPHRASE}\r"
expect "Verifying - Enter PEM pass phrase:"
send -- "${TEST_PASSPHRASE}\r"
expect "Enter pass phrase for"
send -- "${TEST_PASSPHRASE}\r"
expect "Country Name (2 letter code) [DK]:"
send -- "DK\r"
expect "State or Province Name (full name) [Denmark]:"
send -- "Denmark\r"
expect "Locality Name (eg, city) [Copenhagen]:"
send -- "Copenhagen\r"
expect "Organization Name (eg, company) [Trader Internet]:"
send -- "Trader Internet\r"
expect "Organizational Unit Name (eg, section) [Certification Services Division]:"
send -- "Certification Services Division\r"
expect "Common Name (eg, MD Root CA) [Trader Internet Root CA]:"
send -- "Trader Internet Root CA\r"
expect "Email Address [hostmaster@fumlersoft.dk]:"
send -- "hostmaster@fumlersoft.dk\r"
expect eof
EOF
if [ ! -f "${BASE}/CA/ca.crt" ]; then
    echo "Root CA creation failed. Check ${TEST_DIR}/root-ca.log for details."
    exit 1
fi
echo "Root CA creation successful."

# Cleanup existing Sub-CA data if it exists
if [ -d "${BASE}/sub-CAs/${SUB_CA_NAME}" ]; then
    echo "Cleaning up existing Sub-CA data for ${SUB_CA_NAME}..."
    rm -rf "${BASE}/sub-CAs/${SUB_CA_NAME}"
fi

# Test Sub-CA creation
echo "Testing Sub-CA creation..."
# Refactor the expect script for Sub-CA creation to fix input handling
expect <<EOF > "${TEST_DIR}/sub-ca.log" 2>&1
spawn "${BASE}/new-sub-ca.sh" "${SUB_CA_NAME}"
expect "Enter PEM pass phrase:"
send -- "${TEST_PASSPHRASE}\r"
expect "Country Name (2 letter code) [DK]:"
send -- "DK\r"
expect "State or Province Name (full name) [Denmark]:"
send -- "Denmark\r"
expect "Locality Name (eg, city) [Copenhagen]:"
send -- "Copenhagen\r"
expect "Organization Name (eg, company) [Trader Internet]:"
send -- "Trader Internet\r"
expect "Organizational Unit Name (eg, section) [Certification Services Division]:"
send -- "Certification Services Division\r"
expect "Common Name (eg, MD Root CA) [test-sub-ca]:"
send -- "test-sub-ca\r"
expect "Email Address [hostmaster@fumlersoft.dk]:"
send -- "hostmaster@fumlersoft.dk\r"
expect eof
EOF
if [ ! -f "${BASE}/sub-CAs/${SUB_CA_NAME}/CA/${SUB_CA_NAME}.crt" ]; then
    echo "Sub-CA creation failed. Check ${TEST_DIR}/sub-ca.log for details."
    exit 1
fi
echo "Sub-CA creation successful."

# Test Server Certificate creation and signing
echo "Testing Server Certificate creation and signing..."
"${BASE}/new-server-cert.sh" "${SERVER_NAME}" > "${TEST_DIR}/server-cert.log" 2>&1
expect <<EOF >> "${TEST_DIR}/server-cert.log" 2>&1
spawn "${BASE}/sign-server-cert.sh" "${SERVER_NAME}"
expect "Enter PEM pass phrase:"
send "${TEST_PASSPHRASE}\r"
expect eof
EOF
if [ ! -f "${BASE}/certs/${SERVER_NAME}/${SERVER_NAME}.crt" ]; then
    echo "Server certificate creation or signing failed. Check ${TEST_DIR}/server-cert.log for details."
    exit 1
fi
echo "Server certificate creation and signing successful."

# Test User Certificate creation and signing
echo "Testing User Certificate creation and signing..."
"${BASE}/new-user-cert.sh" "${USER_EMAIL}" > "${TEST_DIR}/user-cert.log" 2>&1
expect <<EOF >> "${TEST_DIR}/user-cert.log" 2>&1
spawn "${BASE}/sign-user-cert.sh" "${USER_EMAIL}"
expect "Enter PEM pass phrase:"
send "${TEST_PASSPHRASE}\r"
expect eof
EOF
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.crt" ]; then
    echo "User certificate creation or signing failed. Check ${TEST_DIR}/user-cert.log for details."
    exit 1
fi
echo "User certificate creation and signing successful."

# Test Certificate Revocation
echo "Testing Certificate Revocation..."
expect <<EOF > "${TEST_DIR}/revoke-cert.log" 2>&1
spawn "${BASE}/revoke-cert.sh" "${SERVER_NAME}"
expect "Enter PEM pass phrase:"
send "${TEST_PASSPHRASE}\r"
expect eof
EOF
if ! grep -q "Revoking" "${TEST_DIR}/revoke-cert.log"; then
    echo "Certificate revocation failed. Check ${TEST_DIR}/revoke-cert.log for details."
    exit 1
fi
echo "Certificate revocation successful."

# Test CRL Generation
echo "Testing CRL Generation..."
expect <<EOF > "${TEST_DIR}/crl-generation.log" 2>&1
spawn "${BASE}/gen-root-ca-crl.sh"
expect "Enter PEM pass phrase:"
send "${TEST_PASSPHRASE}\r"
expect eof
EOF
if [ ! -f "${BASE}/CRL/root-ca.crl.pem" ]; then
    echo "CRL generation failed. Check ${TEST_DIR}/crl-generation.log for details."
    exit 1
fi
echo "CRL generation successful."

# Test PKCS#12 Packaging
echo "Testing PKCS#12 Packaging..."
"${BASE}/p12.sh" "${USER_EMAIL}" > "${TEST_DIR}/p12.log" 2>&1
if [ ! -f "${BASE}/certs/users/${USER_EMAIL}/${USER_EMAIL}.p12" ]; then
    echo "PKCS#12 packaging failed. Check ${TEST_DIR}/p12.log for details."
    exit 1
fi
echo "PKCS#12 packaging successful."

echo "All tests completed successfully."

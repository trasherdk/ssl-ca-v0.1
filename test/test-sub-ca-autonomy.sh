#!/bin/bash
# test-sub-ca-autonomy.sh - Test Sub-CA autonomy by running tests within its own directory

set -e

# Dynamically detect the working directory as the root
if [[ $(basename $(realpath $(dirname $0))) == "test" ]]; then
    BASE=$(realpath $(dirname $0)/..)
else
    BASE=$(realpath $(dirname $0))
fi

# Check if the script is run from the correct directory
if [[ -d "${BASE}/sub-CAs" ]]; then
    echo "Running from the correct directory: ${BASE}"
else
    echo "Error: This script must be run from the root directory of the CA structure."
    exit 1
fi

# Define Sub-CA directories
SUB_CA_NORMAL="${BASE}/sub-CAs/test-sub-ca-normal"
SUB_CA_RESTRICTED="${BASE}/sub-CAs/test-sub-ca-restricted"

# Test normal Sub-CA autonomy
cd "$SUB_CA_NORMAL"
echo "Testing autonomy of normal Sub-CA..."

# Define Sub-CA type based on the directory being tested
if [ "$PWD" = "$SUB_CA_NORMAL" ]; then
    SUB_CA_TYPE="normal"
elif [ "$PWD" = "$SUB_CA_RESTRICTED" ]; then
    SUB_CA_TYPE="restricted"
fi

# Ensure the Sub-CA structure is valid before testing
if [ ! -f "CA/ca.crt" ] || [ ! -f "CA/ca.key" ]; then
    echo "Error: Sub-CA structure is invalid. Missing CA certificate or key."
    exit 1
fi

# Ensure the test-environment directory exists before validation
mkdir -p "test-environment"

# Update the test to validate the CA/ca.crt file directly
openssl verify -CAfile "CA/ca.crt" "CA/ca.crt" > "test-environment/ca-verify.log" 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Sub-CA certificate validation failed. Check test-environment/ca-verify.log for details."
    exit 1
fi

./test-sub-ca.sh
cd - > /dev/null

echo "Normal Sub-CA autonomy test passed."

# Test restricted Sub-CA autonomy
cd "$SUB_CA_RESTRICTED"
echo "Testing autonomy of restricted Sub-CA..."

# Define Sub-CA type based on the directory being tested
if [ "$PWD" = "$SUB_CA_NORMAL" ]; then
    SUB_CA_TYPE="normal"
elif [ "$PWD" = "$SUB_CA_RESTRICTED" ]; then
    SUB_CA_TYPE="restricted"
fi

# Remove early exit for restricted Sub-CAs and adjust logic to skip only new-sub-ca.sh
if [ "$SUB_CA_TYPE" = "restricted" ]; then
    echo "Testing restricted Sub-CA autonomy..."
    # Skip new-sub-ca.sh for restricted Sub-CAs
    if [ "$SCRIPT" = "new-sub-ca.sh" ]; then
        echo "Skipping new-sub-ca.sh for restricted Sub-CA: $SUB_CA_NAME"
        continue
    fi
fi

# Run other tests for restricted Sub-CAs
./new-server-cert.sh "www.example.com" "alt1.example.com" "alt2.example.com"
./new-user-cert.sh "user@example.com"
./test-sub-ca.sh

# Ensure the Sub-CA structure is valid before testing
if [ ! -f "CA/ca.crt" ] || [ ! -f "CA/ca.key" ]; then
    echo "Error: Sub-CA structure is invalid. Missing CA certificate or key."
    exit 1
fi

# Ensure the test-environment directory exists before validation
mkdir -p "test-environment"

# Update the test to validate the CA/ca.crt file directly
openssl verify -CAfile "CA/ca.crt" "CA/ca.crt" > "test-environment/ca-verify.log" 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Sub-CA certificate validation failed. Check test-environment/ca-verify.log for details."
    exit 1
fi

./test-sub-ca.sh
cd - > /dev/null

echo "Restricted Sub-CA autonomy test passed."

echo "All Sub-CA autonomy tests passed successfully."
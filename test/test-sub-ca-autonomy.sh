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

# Function to test a Sub-CA's autonomy
test_sub_ca_autonomy() {
    local sub_ca_dir="$1"
    local sub_ca_type="$2"
    local original_dir="$PWD"
    
    echo "Testing autonomy of ${sub_ca_type} Sub-CA..."
    
    # Change to the sub-CA directory
    cd "$sub_ca_dir"
    
    # Ensure the Sub-CA structure is valid
    if [ ! -f "CA/ca.crt" ] || [ ! -f "CA/ca.key" ]; then
        echo "Error: Sub-CA structure is invalid in ${sub_ca_dir}. Missing CA certificate or key."
        cd "$original_dir"
        return 1
    fi
    
    # Create test environment directory
    mkdir -p "test-environment"
    
    # Validate the CA certificate
    openssl verify -CAfile "CA/ca.crt" "CA/ca.crt" > "test-environment/ca-verify.log" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Sub-CA certificate validation failed. Check test-environment/ca-verify.log for details."
        cd "$original_dir"
        return 1
    fi
    
    # Run test scripts
    ./test-server-cert.sh
    ./test-user-cert.sh
    
    # For normal Sub-CAs, also test sub-CA creation capability
    if [ "$sub_ca_type" = "normal" ]; then
        ./test-sub-ca.sh
    fi
    
    cd "$original_dir"
    echo "${sub_ca_type^} Sub-CA autonomy test passed."
}

# Test normal Sub-CA
test_sub_ca_autonomy "$SUB_CA_NORMAL" "normal"

# Test restricted Sub-CA
test_sub_ca_autonomy "$SUB_CA_RESTRICTED" "restricted"

echo "All Sub-CA autonomy tests passed successfully."
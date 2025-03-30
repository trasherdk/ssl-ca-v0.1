#!/bin/bash
# test-sub-ca-autonomy.sh - Test Sub-CA autonomy by running tests within its own directory

set -e

# Dynamically detect the working directory as the root
if [[ $(basename $(realpath $(dirname $0))) == "test" ]]; then
    BASE=$(realpath $(dirname $0)/..)
else
    BASE=$(realpath $(dirname $0))
fi

source "${BASE}/lib/helpers.sh" || exit 1

# Check if the script is run from the correct directory
if [[ -d "${BASE}/sub-CAs" ]]; then
    print_success "Running from the correct directory: ${BASE}"
else
    print_error "This script must be run from the root directory of the CA structure."
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
    
    print_header "Testing autonomy of ${sub_ca_type} Sub-CA..."
    
    print_step "Change to the sub-CA directory: ${sub_ca_dir}"
    cd "$sub_ca_dir"
    
    print_step "Ensure the Sub-CA structure is valid"
    if [ ! -f "CA/ca.crt" ] || [ ! -f "CA/ca.key" ]; then
        print_error "Sub-CA structure is invalid in ${sub_ca_dir}. Missing CA certificate or key."
        cd "$original_dir"
        return 1
    fi
    
    print_step "Create test environment directory"
    mkdir -p "test-environment"
    
    print_step "Validate the CA certificate"
    openssl verify -CAfile "CA/ca.crt" "CA/ca.crt" > "test-environment/ca-verify.log" 2>&1
    if [ $? -ne 0 ]; then
        print_error "Sub-CA certificate validation failed. Check test-environment/ca-verify.log for details."
        cd "$original_dir"
        return 1
    fi
    
    # Test server and user certificate creation for all sub-CAs
    print_step "Testing certificate creation capabilities"
    ./test-server-cert.sh || {
        print_soft_error "Server certificate test failed"
        cd "$original_dir"
        return 1
    }
    ./test-user-cert.sh || {
        print_soft_error "User certificate test failed"
        cd "$original_dir"
        return 1
    }
    
    # Test sub-CA creation - should succeed for normal and fail for restricted
    print_step "Testing sub-CA creation capability"
    if [ "$sub_ca_type" = "normal" ]; then
        ./test-sub-ca.sh || {
            print_soft_error "Sub-CA test failed for normal sub-CA (should succeed)"
            cd "$original_dir"
            return 1
        }
        print_success "Normal sub-CA successfully created new sub-CA"
    else
        # For restricted sub-CA, we expect this to fail
        if ./test-sub-ca.sh &> test-environment/sub-ca-test.log; then
            print_soft_error "Restricted sub-CA was able to create new sub-CA (should fail)"
            cd "$original_dir"
            return 1
        else
            print_success "Restricted sub-CA correctly failed to create new sub-CA"
        fi
    fi
    
    print_step "Return to original directory"
    cd "$original_dir"
    print_success "${sub_ca_type^} Sub-CA autonomy test passed."
}

# Test normal Sub-CA
test_sub_ca_autonomy "$SUB_CA_NORMAL" "normal"

# Test restricted Sub-CA
test_sub_ca_autonomy "$SUB_CA_RESTRICTED" "restricted"

print_success "All Sub-CA autonomy tests passed successfully."
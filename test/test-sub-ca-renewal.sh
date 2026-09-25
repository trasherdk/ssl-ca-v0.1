#!/bin/bash
##
##  test-sub-ca-renewal.sh - Renew a normal and a restricted sub-CA
##

BASE=$(realpath "$(dirname "$0")/..")
TEST_DIR="${BASE}/test-environment"
TEST_PASSPHRASE="testpass"

source "${BASE}/lib/helpers.sh" || exit 1
export CRL_URL="${CRL_URL:-http://crl.example.test/root-ca.crl.pem}"

print_header "Testing Sub-CA certificate renewal"

renew_one() {
    local name="$1"
    local restricted="$2"
    local cert="${BASE}/sub-CAs/${name}/CA/ca.crt"
    local registry="${BASE}/certs/sub-CAs/${name}/${name}/ca.crt"

    if [ ! -f "${cert}" ]; then
        print_error "Sub-CA ${name} not found. Run test-sub-ca.sh first."
    fi

    local serial_before subject_before
    serial_before=$(openssl x509 -in "${cert}" -noout -serial | cut -d= -f2)
    subject_before=$(openssl x509 -in "${cert}" -noout -subject)

    print_step "Renewing ${name}..."
    local test_pipe="${TEST_DIR}/test_pipe_renew_${name}"
    mkdir -p "${TEST_DIR}"
    mkfifo "$test_pipe"
    tee "${TEST_DIR}/renew-${name}.log" < "$test_pipe" &
    local tee_pid=$!

    expect <<EOF > "$test_pipe" 2>&1
log_user 1
set timeout 60
spawn "${BASE}/renew-sub-ca.sh" "${name}"
expect {
    "Enter pass phrase*" {
        send "${TEST_PASSPHRASE}\r"
        exp_continue
    }
    "Sign the certificate*" {
        send "y\r"
        exp_continue
    }
    "1 out of 1 certificate requests certified*" {
        send "y\r"
        exp_continue
    }
    timeout {
        puts "\nTimeout waiting for prompt"
        exit 1
    }
    eof
}
EOF
    local result=$?
    wait "$tee_pid"
    rm -f "$test_pipe"
    if [ $result -ne 0 ]; then
        print_error "renew-sub-ca.sh failed for ${name}. Check ${TEST_DIR}/renew-${name}.log."
    fi

    local serial_after subject_after text
    serial_after=$(openssl x509 -in "${cert}" -noout -serial | cut -d= -f2)
    subject_after=$(openssl x509 -in "${cert}" -noout -subject)
    text=$(openssl x509 -in "${cert}" -text -noout)

    if [ "${serial_before}" = "${serial_after}" ]; then
        print_error "${name} serial did not change."
    fi
    if [ "${subject_before}" != "${subject_after}" ]; then
        print_error "${name} subject changed during renewal."
    fi
    if ! echo "${text}" | grep -q "CA:TRUE"; then
        print_error "${name} lost CA:TRUE."
    fi
    if [ "${restricted}" = "yes" ]; then
        if ! echo "${text}" | grep -q "pathlen:0"; then
            print_error "Restricted sub-CA ${name} lost pathlen:0."
        fi
    elif echo "${text}" | grep -q "pathlen"; then
        print_error "Normal sub-CA ${name} gained a pathlen constraint."
    fi
    if ! openssl verify -CAfile "${cert}" "${cert}" >/dev/null 2>&1; then
        print_error "${name} chain verification failed after renewal."
    fi
    if [ ! -f "${registry}" ]; then
        print_error "Registry copy missing for ${name}."
    fi
    local registry_serial
    registry_serial=$(openssl x509 -in "${registry}" -noout -serial | cut -d= -f2)
    if [ "${registry_serial}" != "${serial_after}" ]; then
        print_error "Registry copy for ${name} was not updated."
    fi
    if [ -z "$(ls "${BASE}/sub-CAs/${name}/CA/backup/")" ]; then
        print_error "No backup stored for ${name}."
    fi
    print_success "${name} renewed (${serial_before} -> ${serial_after})."
}

renew_one "test-sub-ca-normal" "no"
renew_one "test-sub-ca-restricted" "yes"
print_success "Sub-CA renewal tests passed."

# TODO - Planned Improvements and Missing Features

## Checklist
- [x] 1. Certificate Expiry Notification and Thresholds
- [x] 2. Sub-CA Pathlen Constraints
- [ ] 3. CRL Management
- [ ] 4. Audit Logs
- [ ] 5. Script for Viewing Certificate Details
- [ ] 6. Support for OCSP (Online Certificate Status Protocol)
- [ ] 7. Enhanced Error Handling
- [ ] 8. Documentation for Security Best Practices
- [ ] 9. Script for Revoking Certificates by Serial Number
- [ ] 10. Automated Testing
- [x] 11. PKCS#12 Password Management
  - Split into server-p12.sh and user-p12.sh
  - Added verification after export
  - Improved error handling and logging
- [ ] 12. Periodic CRL Automation
- [ ] 13. Create Svelte 5/SvelteKit Web Interface

## 1. Certificate Expiry Notification and Thresholds ✓
- Add a script to check for certificates nearing expiration.
- Notify the administrator for both root CA, sub-CAs, and issued certificates.
- **Status**: Completed and Verified.
  - The `check-expiry.sh` script has:
    - Configurable thresholds via environment variables
    - Email extraction from certificates (with fallback to .env)
    - Proper error handling and logging
    - Independent operation in Sub-CAs
    - TLS-encrypted SMTP with client certificate authentication
    - Debug mode for troubleshooting (-d flag)
    - Clean, concise output for normal operation
    - Verified email delivery with test-expiry.sh
  - Future enhancements (optional):
    - Multiple notification recipients
    - Rate limiting for notifications
    - HTML email format option
    - Configurable notification thresholds

## 2. Sub-CA Pathlen Constraints ✓
- Implement proper pathlen constraints for restricted sub-CAs.
- **Status**: Completed.
  - Implementation details:
    - Restricted sub-CAs use `pathlen:0` constraint
    - Proper key usage flags (`keyCertSign,cRLSign`)
    - Early validation in `new-sub-ca.sh` to prevent restricted CAs from creating sub-CAs
    - Comprehensive test coverage in `test-sub-ca-autonomy.sh`
  - Security features:
    - Two-tier CA hierarchy (normal and restricted sub-CAs)
    - Proper certificate chain validation
    - Autonomous operation for end-entity certificate signing



## 3. CRL Management
- Create a script to automatically regenerate the Certificate Revocation List (CRL) periodically for both root CA and sub-CAs.
- Ensure revoked certificates are properly distributed.
- **Status**: Partially implemented.
  - The `gen-root-ca-crl.sh` script generates a CRL for the root CA.
  - Missing features:
    - Automate CRL generation periodically.
    - Add support for sub-CAs.

## 4. Audit Logs
- Add logging to all scripts to track operations like certificate creation, renewal, and revocation.
- Store logs in a centralized location for auditing purposes.

## 5. Script for Viewing Certificate Details
- Add a utility script to display details of a certificate (e.g., subject, issuer, validity period, extensions).
- Help administrators quickly inspect certificates.

## 6. Support for OCSP (Online Certificate Status Protocol)
- Add scripts to generate OCSP responses for real-time certificate status checking.
- Useful for environments requiring dynamic revocation checks.

## 7. Enhanced Error Handling
- Improve error handling in all scripts to provide more descriptive messages and fail gracefully.

## 8. Documentation for Security Best Practices
- Add a section in the README or a separate document explaining best practices for securing the CA:
  - Protecting private keys.
  - Using hardware security modules (HSMs).
  - Regularly rotating keys and certificates.

## 9. Script for Revoking Certificates by Serial Number
- Add a script to revoke certificates by their serial number for more flexibility.

## 10. Automated Testing
- [x] Create Root CA test script with comprehensive verification
- [x] Create Sub-CA test script
- [x] Create server certificate test script (test-server-cert.sh)
- [x] Create user certificate test script (test-user-cert.sh)
- [ ] Create CRL test script
- [x] Create PKCS#12 test script (test-p12-certs.sh)

### 10.1 Core Functionality Tests
- [x] Test Root CA creation and verification
- [x] Test Sub-CA creation and verification
- [x] Test certificate chain validation
- [ ] Test CRL generation and validation: Not yet tested
- [ ] Test certificate renewal processes: Not yet tested
- [x] Test PKCS#12 file generation and password handling: Completed with test-p12-certs.sh.
- [x] Test sub-CA creation with different pathlen constraints: Completed with test-sub-ca-autonomy.sh

### 10.2 Error Handling Tests
- [ ] Test invalid certificate signing requests
- [ ] Test revocation of already-revoked certificates
- [x] Test expired certificate handling (test-check-expiry.sh)
- [x] Test invalid password scenarios (test-p12-certs.sh)
- [ ] Test malformed configuration files

### 10.3 Integration Tests
- [x] Test complete workflow from root CA to end-entity certificates (test-root-ca.sh, test-sub-ca.sh)
- [ ] Test certificate renewal workflow
- [ ] Test CRL update and distribution process
- [x] Test expiry notification system (test-check-expiry.sh, test-expiry.sh)
- [ ] Improve sub-CA management:
  - [ ] Store sub-CA certificates in both ./certs/sub-CAs/ (registry) and ./sub-CAs/ (operational)
  - [ ] Update check-expiry.sh to check sub-CA certs from ./certs/sub-CAs/
  - [ ] Allow detaching sub-CAs while maintaining certificate tracking
  - [ ] Each sub-CA should follow same pattern for its own sub-CAs

### 10.4 Security Tests
- [x] Test private key protection mechanisms (test-root-ca.sh)
- [x] Test permission settings on sensitive files (test-root-ca.sh)
- [x] Test password strength requirements (test-p12-certs.sh)
- [x] Test certificate constraints enforcement (test-sub-ca-autonomy.sh)

### 10.5 Performance Tests
- [ ] Test CRL generation with large number of certificates
- [ ] Test concurrent certificate operations
- [ ] Test system behavior under load

### 10.6 Compatibility Tests
- Test certificates with different key sizes
- Test various certificate extensions
- Test OpenSSL version compatibility
- Test browser/client compatibility for generated certificates

## 11. PKCS#12 Password Management
- Enhance the `p12.sh` script to allow administrators to specify or generate strong passwords for `.p12` files.

## 12. Periodic CRL Automation
- Create a script or cron job to periodically regenerate CRLs for both root CA and sub-CAs.

## 13. Create Svelte 5/SvelteKit Web Interface
- Create a standalone modern web interface using Svelte 5 and SvelteKit
- Technical Stack:
  - Frontend: Svelte 5 with SvelteKit
  - Database: MySQL for certificate and user storage
  - X.509 Operations: @peculiar/x509 for certificate handling
  - No dependency on existing bash scripts
- Features to include:
  - Dashboard showing CA hierarchy and certificate status
  - Certificate lifecycle management (create, revoke, renew)
  - Real-time expiry monitoring and notifications
  - CRL and OCSP management
  - User management and access control
  - Audit log viewer
  - Responsive design for desktop and mobile
  - Database schema for storing:
    - CA hierarchy
    - Certificates and keys
    - User accounts and permissions
    - Audit logs
    - Notification settings
- **Status**: Not started.

## Additional Notes
- Updated `new-root-ca.sh` to include a check that prevents running the script in a directory where a CA certificate already exists. This ensures that the script is only used to create a new root CA in a clean directory. A stern warning is displayed if the condition is violated.
- [x] Fix issues with `test-root-ca.sh`, `test-server-cert.sh`, and `test-user-cert.sh` scripts.
- [x] Ensure all scripts run successfully without manual intervention.
- [x] Resolve user certificate signing issues and verify successful execution.
- [x] Validate that all certificates are correctly generated and verified.


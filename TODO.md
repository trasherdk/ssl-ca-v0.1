# TODO - Planned Improvements and Missing Features

## Checklist
- [ ] 1. Certificate Expiry Notification and Thresholds
- [x] 2. Sub-CA Pathlen Constraints
- [ ] 3. CRL Management
- [ ] 4. Audit Logs
- [ ] 5. Script for Viewing Certificate Details
- [ ] 6. Support for OCSP (Online Certificate Status Protocol)
- [ ] 7. Enhanced Error Handling
- [ ] 8. Documentation for Security Best Practices
- [ ] 9. Script for Revoking Certificates by Serial Number
- [ ] 10. Automated Testing
- [ ] 11. PKCS#12 Password Management
- [ ] 12. Periodic CRL Automation

## 1. Certificate Expiry Notification and Thresholds
- Add a script to check for certificates nearing expiration.
- Notify the administrator for both root CA, sub-CAs, and issued certificates.
- **Status**: Partially Implemented.
  - The `check-expiry.sh` script now has:
    - Configurable thresholds via environment variables
    - Email extraction from certificates (with fallback to .env)
    - Proper error handling and logging
    - Independent operation in Sub-CAs
  - Completed:
    - Email delivery working with proper TLS authentication
    - Root CA properly trusted in system store
    - test-email.sh script for testing email delivery
    - Fixed MAIL FROM authentication issues
  - Remaining tasks:
    - Add unit tests for expiry checks
    - Consider adding alternative notification methods (e.g., syslog)

## 2. Sub-CA Pathlen Constraints
- Enable normal Sub-CAs to create other Sub-CAs by removing pathlen constraint.
- Support restricted Sub-CAs that cannot create further Sub-CAs.
- **Status**: Completed.
  - Implemented in root CA configuration.
  - Added support for both normal and restricted Sub-CAs.
  - All tests passing.

## 3. CRL Management
- Create a script to automatically regenerate the Certificate Revocation List (CRL) periodically for both root CA and sub-CAs.
- Ensure revoked certificates are properly distributed.
- **Status**: Partially implemented.
  - The `gen-root-ca-crl.sh` script generates a CRL for the root CA.
  - Missing features:
    - Automate CRL generation periodically.
    - Add support for sub-CAs.

## 3. Audit Logs
- Add logging to all scripts to track operations like certificate creation, renewal, and revocation.
- Store logs in a centralized location for auditing purposes.

## 4. Script for Viewing Certificate Details
- Add a utility script to display details of a certificate (e.g., subject, issuer, validity period, extensions).
- Help administrators quickly inspect certificates.

## 5. Support for OCSP (Online Certificate Status Protocol)
- Add scripts to generate OCSP responses for real-time certificate status checking.
- Useful for environments requiring dynamic revocation checks.

## 6. Enhanced Error Handling
- Improve error handling in all scripts to provide more descriptive messages and fail gracefully.

## 7. Documentation for Security Best Practices
- Add a section in the README or a separate document explaining best practices for securing the CA:
  - Protecting private keys.
  - Using hardware security modules (HSMs).
  - Regularly rotating keys and certificates.

## 8. Script for Revoking Certificates by Serial Number
- Add a script to revoke certificates by their serial number for more flexibility.

## 9. Automated Testing
- [x] Create Root CA test script with comprehensive verification
- [x] Create Sub-CA test script
- [ ] Create server certificate test script
- [ ] Create user certificate test script
- [ ] Create CRL test script
- [ ] Create PKCS#12 test script

### 9.1 Core Functionality Tests
- Test certificate chain validation
- Test CRL generation and validation
- Test certificate renewal processes
- Test PKCS#12 file generation and password handling
- Test sub-CA creation with different pathlen constraints

### 9.2 Error Handling Tests
- Test invalid certificate signing requests
- Test revocation of already-revoked certificates
- Test expired certificate handling
- Test invalid password scenarios
- Test malformed configuration files

### 9.3 Integration Tests
- Test complete workflow from root CA to end-entity certificates
- Test certificate renewal workflow
- Test CRL update and distribution process
- Test expiry notification system

### 9.4 Security Tests
- Test private key protection mechanisms
- Test permission settings on sensitive files
- Test password strength requirements
- Test certificate constraints enforcement

### 9.5 Performance Tests
- Test CRL generation with large number of certificates
- Test concurrent certificate operations
- Test system behavior under load

### 9.6 Compatibility Tests
- Test certificates with different key sizes
- Test various certificate extensions
- Test OpenSSL version compatibility
- Test browser/client compatibility for generated certificates

## 10. PKCS#12 Password Management
- Enhance the `p12.sh` script to allow administrators to specify or generate strong passwords for `.p12` files.

## 11. Periodic CRL Automation
- Create a script or cron job to periodically regenerate CRLs for both root CA and sub-CAs.

## 12. Configurable Expiry Thresholds for Notifications
- Modify `check-expiry.sh` to allow administrators to configure the expiry threshold (e.g., 30 days, 60 days).

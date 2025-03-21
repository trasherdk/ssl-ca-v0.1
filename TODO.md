# TODO - Planned Improvements and Missing Features

## Checklist
- [x] 1. Certificate Expiry Notification
- [ ] 2. CRL Management
- [ ] 3. Audit Logs
- [ ] 4. Script for Viewing Certificate Details
- [ ] 5. Support for OCSP (Online Certificate Status Protocol)
- [ ] 6. Enhanced Error Handling
- [ ] 7. Documentation for Security Best Practices
- [ ] 8. Script for Revoking Certificates by Serial Number
- [ ] 9. Automated Testing
- [ ] 10. PKCS#12 Password Management
- [ ] 11. Periodic CRL Automation
- [ ] 12. Configurable Expiry Thresholds for Notifications

## 1. Certificate Expiry Notification
- Add a script to check for certificates nearing expiration.
- Notify the administrator for both root CA, sub-CAs, and issued certificates.
- **Status**: Partially implemented.
  - The `check-expiry.sh` script exists but could be enhanced:
    - Add configurable thresholds for expiry notifications.
    - Improve error handling and logging.

## 2. CRL Management
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
- Add a script to test the entire CA setup, including creating, signing, revoking, and renewing certificates.
- Ensure all scripts work as expected.

## 10. PKCS#12 Password Management
- Enhance the `p12.sh` script to allow administrators to specify or generate strong passwords for `.p12` files.

## 11. Periodic CRL Automation
- Create a script or cron job to periodically regenerate CRLs for both root CA and sub-CAs.

## 12. Configurable Expiry Thresholds for Notifications
- Modify `check-expiry.sh` to allow administrators to configure the expiry threshold (e.g., 30 days, 60 days).

# ssl-ca - openssl certificate authority

## Overview

This project provides a set of shell scripts to manage a simple Certificate Authority (CA) using OpenSSL. It allows users to create, sign, revoke, and manage certificates for servers and users. The scripts are designed to simplify the process of generating and managing SSL/TLS certificates.

## Features

- **Root CA Management**: Create and manage a self-signed root CA.
- **Sub-CA Management**: Create two types of sub-CAs:
  - **Normal Sub-CAs**: Can issue both certificates and further sub-CAs, with no pathlen constraint.
  - **Restricted Sub-CAs**: Can only issue end-entity certificates (CA:FALSE), cannot create further sub-CAs.
- **Server Certificates**: Generate and sign certificates for web servers.
- **User Certificates**: Generate and sign certificates for individual users (e.g., for S/MIME or email encryption).
- **Certificate Revocation**: Revoke certificates and manage a Certificate Revocation List (CRL).
- **PKCS#12 Packaging**: Package user certificates into `.p12` files for easy import into browsers or email clients.
- **Configuration Management**: Automatically generate OpenSSL configuration files for various operations.
- **Certificate Expiry Monitoring** ✓: 
  - Automated expiry checks for all certificates with configurable thresholds
  - Secure email notifications to certificate owners:
    - Email addresses extracted from certificates (with .env fallback)
    - TLS-encrypted SMTP with client certificate authentication
    - Root CA properly trusted in system certificate store
  - Each Sub-CA operates independently with its own expiry monitoring
  - Debug mode (-d flag) for detailed troubleshooting
  - Clean, concise output for normal operation
  - Includes test scripts for verifying notifications
  - Includes test-email.sh script for verifying email delivery

## Sub-CA Types and Certificate Chain Depth

The system supports two types of Sub-CAs with different capabilities:

### Normal Sub-CAs
- Created without the `no-sub-ca` option
- Have `CA:TRUE` in their basicConstraints
- No pathlen constraint, allowing them to create further sub-CAs
- Can issue both end-entity certificates and create other sub-CAs
- Ideal for departmental or organizational CAs that need to manage their own certificate hierarchy

### Restricted Sub-CAs
- Created with the `no-sub-ca` option
- Have `CA:FALSE` in their basicConstraints
- Cannot create further sub-CAs
- Can only issue end-entity certificates (server/user certificates)
- Suitable for specific services or departments that only need to issue certificates

To create a Sub-CA, use the `new-sub-ca.sh` script with the appropriate option:
```sh
# Create a normal Sub-CA that can issue sub-CAs
./new-sub-ca.sh my-department-ca

# Create a restricted Sub-CA that can only issue certificates
./new-sub-ca.sh my-service-ca no-sub-ca
```

## Usage

### Root CA

1. **Create a Root CA**:
   Run `new-root-ca.sh` to generate a self-signed root CA. This root CA will be used to sign all other certificates.

2. **Generate and Sign Certificates**:
   - Use `new-server-cert.sh` and `sign-server-cert.sh` for server certificates.
   - Use `new-user-cert.sh` and `sign-user-cert.sh` for user certificates.

3. **Revoke Certificates**:
   Use `revoke-cert.sh` to revoke a certificate.

4. **Generate a CRL**:
   Run `gen-root-ca-crl.sh` to generate or update the Certificate Revocation List.

5. **Renew the Root CA Certificate**:
   Run `renew-root-ca.sh` to renew the root CA certificate while retaining the existing private key:
   ```sh
   ./renew-root-ca.sh
   ```

### Sub-CA

1. **Create a Sub-CA**:
   Run `new-sub-ca.sh <sub-ca-name> [no-sub-ca]` to create a sub-CA signed by the root CA. This will:
   - Dynamically calculate the `pathlen` based on the parent CA's certificate.
   - Generate a private key and certificate for the sub-CA.
   - Initialize the sub-CA's directory structure.
   - Copy the necessary scripts into the sub-CA directory, allowing it to operate independently.

   - If `no-sub-ca` is specified, the sub-CA will be restricted to issuing only user/host certificates and will not be able to create further sub-CAs.

2. **Operate the Sub-CA**:
   Navigate to the sub-CA directory (`sub-CAs/<sub-ca-name>/`) and use the provided scripts:
   - `new-server-cert.sh` and `sign-server-cert.sh` for server certificates.
   - `new-user-cert.sh` and `sign-user-cert.sh` for user certificates.
   - `revoke-cert.sh` to revoke certificates.
   - `p12.sh` to package user certificates into `.p12` files.
   - `new-sub-ca.sh` to create further sub-CAs (if allowed).

3. **Revoke Certificates in the Sub-CA**:
   Use the `revoke-cert.sh` script in the sub-CA directory to revoke certificates issued by the sub-CA.

4. **Renew a Sub-CA Certificate**:
   Run `renew-sub-ca.sh <sub-ca-name>` to renew a sub-CA certificate while retaining the existing private key:
   ```sh
   ./renew-sub-ca.sh <sub-ca-name>
   ```

   Replace `<sub-ca-name>` with the name of the sub-CA to be renewed.

### Server Certificates

1. **Renew a Server Certificate**:
   Run `renew-server-cert.sh <server-name>` to renew a server certificate while retaining the existing private key:
   ```sh
   ./renew-server-cert.sh <server-name>
   ```

   Replace `<server-name>` with the name of the server certificate to be renewed.

### User Certificates

1. **Renew a User Certificate**:
   Run `renew-user-cert.sh <user-email>` to renew a user certificate while retaining the existing private key:
   ```sh
   ./renew-user-cert.sh <user-email>
   ```

   Replace `<user-email>` with the email address of the user certificate to be renewed.

### Certificate Expiry Notification

1. **Check for Expiring Certificates**:
   Run `check-expiry.sh` to check for certificates nearing expiration and send email notifications. The script will:
   - Extract email addresses from certificates for notifications
   - Use different thresholds for different certificate types
   - Work independently in both root CA and Sub-CA contexts
   ```sh
   # In root CA:
   ./check-expiry.sh
   
   # In any Sub-CA:
   cd sub-CAs/my-sub-ca
   ./check-expiry.sh
   ```
   
   Configure expiry thresholds in `.env` (optional, defaults shown):
   ```sh
   ROOT_CA_THRESHOLD=90   # Days before root CA expiry to notify
   SUB_CA_THRESHOLD=60    # Days before Sub-CA expiry to notify
   CERT_THRESHOLD=30      # Days before end-entity cert expiry to notify
   EMAIL=admin@example.com # Fallback email if none in certificate
   ```

   - The script checks the root CA, sub-CAs, and issued certificates.
   - By default, it sends notifications for certificates expiring within 30 days.
   - Update the `EMAIL` variable in the script to set the administrator's email address.

## Directory Structure

### Root CA
```
CA/
├── ca.key              # Root CA private key
├── ca.crt              # Root CA certificate
├── ca.db.certs/        # Issued certificates
├── ca.db.serial        # Serial number for issued certificates
├── ca.db.index         # Database index for issued certificates
```

### Sub-CA
```
sub-CAs/
└── <sub-ca-name>/
    ├── CA/
    │   ├── <sub-ca-name>.key  # Sub-CA private key
    │   ├── <sub-ca-name>.crt  # Sub-CA certificate
    │   ├── ca.db.certs/       # Issued certificates
    │   ├── ca.db.serial       # Serial number for issued certificates
    │   ├── ca.db.index        # Database index for issued certificates
    ├── certs/                 # Directory for storing certificates
    ├── crl/                   # Directory for storing CRLs
    ├── new-user-cert.sh       # Script for creating user certificates
    ├── sign-user-cert.sh      # Script for signing user certificates
    ├── new-server-cert.sh     # Script for creating server certificates
    ├── sign-server-cert.sh    # Script for signing server certificates
    ├── revoke-cert.sh         # Script for revoking certificates
    ├── p12.sh                 # Script for packaging certificates into .p12 files
```

## Testing

The project includes automated test scripts to verify the correct operation of the CA infrastructure:

### Root CA Testing
- `test-root-ca.sh`: Verifies Root CA creation and configuration
  - Automated certificate creation with proper attributes
  - Security permissions verification
  - Certificate extensions validation
  - Key pair consistency checks
  - CA database initialization

### Running Tests
```sh
# Test Root CA setup
./test-root-ca.sh
```

## Example Workflow

### Root CA
1. Create the root CA:
   ```sh
   ./new-root-ca.sh
   ```

2. Generate and sign a server certificate:
   ```sh
   ./new-server-cert.sh www.example.com
   ./sign-server-cert.sh www.example.com
   ```

3. Generate and sign a user certificate:
   ```sh
   ./new-user-cert.sh user@example.com
   ./sign-user-cert.sh user@example.com
   ./p12.sh user@example.com
   ```

4. Revoke a certificate:
   ```sh
   ./revoke-cert.sh www.example.com
   ```

5. Renew the root CA certificate:
   ```sh
   ./renew-root-ca.sh
   ```

### Sub-CA
1. Create a sub-CA that can issue further sub-CAs:
   ```sh
   ./new-sub-ca.sh intermediate-ca
   ```

2. Create a sub-CA that can only issue user/host certificates:
   ```sh
   ./new-sub-ca.sh issuing-ca no-sub-ca
   ```

3. Navigate to the sub-CA directory and create another sub-CA (if allowed):
   ```sh
   cd sub-CAs/intermediate-ca
   ./new-sub-ca.sh sub-intermediate-ca
   ```

4. Generate and sign a server certificate in the sub-CA:
   ```sh
   ./new-server-cert.sh www.subdomain.com
   ./sign-server-cert.sh www.subdomain.com
   ```

5. Generate and sign a user certificate in the sub-CA:
   ```sh
   ./new-user-cert.sh user@subdomain.com
   ./sign-user-cert.sh user@subdomain.com
   ./p12.sh user@subdomain.com
   ```

6. Revoke a certificate in the sub-CA:
   ```sh
   ./revoke-cert.sh www.subdomain.com
   ```

7. Renew a sub-CA certificate:
   ```sh
   ./renew-sub-ca.sh intermediate-ca
   ```

### Server Certificates
1. Renew a server certificate:
   ```sh
   ./renew-server-cert.sh www.example.com
   ```

### User Certificates
1. Renew a user certificate:
   ```sh
   ./renew-user-cert.sh user@example.com
   ```

### Certificate Expiry Notification
1. Check for expiring certificates:
   ```sh
   ./check-expiry.sh
   ```

   - Example output:
     ```
     Checking root CA certificate...
     Certificate Root CA is expiring in 25 days (Dec 15 23:59:59 2023 GMT).
     Checking sub-CA certificates...
     Certificate Sub-CA intermediate-ca is expiring in 10 days (Dec 1 23:59:59 2023 GMT).
     Checking issued certificates...
     Certificate www.example.com is expiring in 5 days (Nov 26 23:59:59 2023 GMT).
     Certificate expiry check completed.
     ```

## Notes

- Sub-CAs are fully independent of the root CA once created.
- Use the `no-sub-ca` option to restrict a sub-CA to issuing only user/host certificates.
- Ensure that the root CA's private key is securely stored and protected with a strong password.
- Always back up the CA and sub-CA directories to prevent data loss.

## License

This project is licensed under the GNU General Public License v2. See the `COPYING` file for details.


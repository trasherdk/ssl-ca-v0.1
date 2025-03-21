# ssl-ca - openssl certificate authority

## Overview

This project provides a set of shell scripts to manage a simple Certificate Authority (CA) using OpenSSL. It allows users to create, sign, revoke, and manage certificates for servers and users. The scripts are designed to simplify the process of generating and managing SSL/TLS certificates.

## Features

- **Root CA Management**: Create and manage a self-signed root CA.
- **Server Certificates**: Generate and sign certificates for web servers.
- **User Certificates**: Generate and sign certificates for individual users (e.g., for S/MIME or email encryption).
- **Certificate Revocation**: Revoke certificates and manage a Certificate Revocation List (CRL).
- **PKCS#12 Packaging**: Package user certificates into `.p12` files for easy import into browsers or email clients.
- **Configuration Management**: Automatically generate OpenSSL configuration files for various operations.

## Requirements

- A Unix-based system with a working shell (`sh` or `bash`).
- OpenSSL version 0.9.4 or above (tested with 0.95a).
- Basic knowledge of SSL/TLS and certificate management.

## Usage

1. **Create a Root CA**:
   Run `new-root-ca.sh` to generate a self-signed root CA. This root CA will be used to sign all other certificates.

2. **Generate a Server Certificate**:
   Use `new-server-cert.sh <domain>` to create a certificate signing request (CSR) for a server. Then, sign it using `sign-server-cert.sh <domain>`.

3. **Generate a User Certificate**:
   Use `new-user-cert.sh <email>` to create a CSR for a user. Sign it using `sign-user-cert.sh <email>`. Optionally, package it into a `.p12` file using `p12.sh <email>`.

4. **Revoke a Certificate**:
   Use `revoke-cert.sh <name>` to revoke a certificate. The revoked certificate will be added to the CRL.

5. **Generate a CRL**:
   Run `gen-root-ca-crl.sh` to generate or update the Certificate Revocation List.

## Directory Structure

- **CA/**: Contains the root CA's private key, certificate, and database files.
- **certs/**: Stores issued certificates.
- **certs-revoked/**: Stores revoked certificates.
- **config/**: Contains dynamically generated OpenSSL configuration files.
- **CRL/**: Stores the Certificate Revocation List.

## Example Workflow

1. Create a root CA:
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
   ./gen-root-ca-crl.sh
   ```

## Notes

- The scripts are designed to be modular and can be customized to suit specific needs.
- Ensure that the root CA's private key is securely stored and protected with a strong password.
- Always back up the CA directory to prevent data loss.

## License

This project is licensed under the GNU General Public License v2. See the `COPYING` file for details.


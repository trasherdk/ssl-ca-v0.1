# ssl-ca - openssl certificate authority

## Overview

This project provides a set of shell scripts to manage a simple Certificate Authority (CA) using OpenSSL. It allows users to create, sign, revoke, and manage certificates for servers and users. The scripts are designed to simplify the process of generating and managing SSL/TLS certificates.

## Features

- **Root CA Management**: Create and manage a self-signed root CA.
- **Sub-CA Management**: Create sub-CAs for specific purposes, such as managing certificates for a particular website or service. Sub-CAs operate independently of the root CA and can optionally create further sub-CAs or be restricted to issuing only user/host certificates.
- **Server Certificates**: Generate and sign certificates for web servers.
- **User Certificates**: Generate and sign certificates for individual users (e.g., for S/MIME or email encryption).
- **Certificate Revocation**: Revoke certificates and manage a Certificate Revocation List (CRL).
- **PKCS#12 Packaging**: Package user certificates into `.p12` files for easy import into browsers or email clients.
- **Configuration Management**: Automatically generate OpenSSL configuration files for various operations.

## Pathlen and Certificate Chain Depth

The `pathlen` constraint in the `basicConstraints` extension determines the maximum depth of the certificate chain below the current certificate:
- If the root CA does not have a `pathlen` constraint, there is no restriction on the depth of the chain, and sub-CAs will inherit this unrestricted behavior unless explicitly configured otherwise.
- If the root CA or any intermediate CA has a `pathlen` constraint, sub-CAs created under it will have their `pathlen` decremented by 1, limiting the chain depth accordingly.
- A `pathlen` of `0` means the certificate cannot issue any further sub-CAs.

The `new-sub-ca.sh` script dynamically calculates the `pathlen` for sub-CAs based on the parent CA's certificate. Additionally, the `no-sub-ca` option can be used to explicitly restrict a sub-CA from issuing further sub-CAs.

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

## Notes

- Sub-CAs are fully independent of the root CA once created.
- Use the `no-sub-ca` option to restrict a sub-CA to issuing only user/host certificates.
- Ensure that the root CA's private key is securely stored and protected with a strong password.
- Always back up the CA and sub-CA directories to prevent data loss.

## License

This project is licensed under the GNU General Public License v2. See the `COPYING` file for details.


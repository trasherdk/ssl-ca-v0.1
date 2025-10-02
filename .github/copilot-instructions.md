Guidance for AI coding agents working on this repository

Purpose
- This repo is a collection of shell scripts that implement a small OpenSSL-based Certificate Authority (root CA + optional sub-CAs). Primary workflows are: creating root CA, creating sub-CAs, issuing server/user certificates, revoking certs, generating CRLs, and packaging user certs to PKCS#12.

Big picture (what to know first)
- Root CA lives under `CA/` (important files: `ca.key`, `ca.crt`, `ca.db.index`, `ca.db.serial`, `ca.db.certs/`). Many scripts assume these exact filenames and locations.
- Top-level scripts operate against the repository root. Examples: `new-root-ca.sh`, `new-server-cert.sh`, `sign-server-cert.sh`, `revoke-cert.sh`, `gen-root-ca-crl.sh`, `check-expiry.sh`, `p12.sh`.
- Sub-CAs are created under `sub-CAs/` and are self-contained (their own `CA/`, `certs/`, scripts copied from the root). Sub-CA scripts mirror root-level scripts but use a relative base path.
- OpenSSL configuration snippets are generated on-the-fly into `config/` or per-certificate directories (see `new-root-ca.sh`, `new-server-cert.sh`). Follow the pattern used by existing scripts when adding new operations (generate a config file, call `openssl` with that config, then clean up).

Project conventions and patterns
- Shell-only codebase: expect bash/sh portable idioms. Use `realpath $(dirname $0)` to compute the repository base in scripts; mimic this when adding new scripts.
- File and directory permissions: scripts create directories with restrictive permissions (e.g., `chmod g-rwx,o-rwx`). Preserve this behavior for private keys and CA dirs.
- Naming conventions: certificate directories are under `certs/<commonName>/` and files are named `<commonName>.key`, `<commonName>.csr`, `<commonName>.crt`, `<commonName>.p12` for user certs.
- CA database: scripts rely on `CA/ca.db.index` and `CA/ca.db.serial`. Do not alter these names or formats; instead extend logic by reading/writing those files in the same way.
- Config generation: scripts create temporary OpenSSL config files under `config/` or certificate subdirectories and often remove them afterward. When adding features, follow the same pattern and avoid committing ephemeral configs.

Critical developer workflows (how to run things)
- Create root CA (must be run once): `./new-root-ca.sh` — generates `CA/ca.key` and `CA/ca.crt` and `config/root-ca.conf`.
- Create a server CSR: `./new-server-cert.sh example.com [alt.domains...]` — creates `certs/example.com/` and a CSR.
- Sign a server CSR: `./sign-server-cert.sh example.com [alt.domains...]` — uses `openssl ca -config <generated-config>` and updates CA database files.
- Revoke a certificate: `./revoke-cert.sh example.com` — interactive selection from `CA/ca.db.index` and then calls `scripts/revoke.sh`.
- Package a user cert to .p12: `./p12.sh user@example.com` — requires `certs/users/<user>/` with key/crt and `CA/ca.crt`.
- Check expiries and notify: `./check-expiry.sh` — relies on system `mail` utility; update `EMAIL` in the script to change recipient.

Integration points & external dependencies
- Requires OpenSSL command-line tools (`openssl`) and standard Unix utilities (`realpath`, `mail`, `date`, `sed`, `egrep`, `find`). Tests and CI should run on a Linux-like environment.
- Email notification uses the local `mail` program; CI environments may not have this — stub or mock when testing.
- Scripts write and read the on-disk CA state (private keys, serials, index). Treat these as sensitive; do not print private keys or include them in logs.

Examples to reference when generating code
- Create temp OpenSSL config: `new-root-ca.sh` and `new-server-cert.sh` (look at how `cat > $CONFIG <<EOT` is used and how `req` and `v3_*` sections are templated).
- Sign operation: `sign-server-cert.sh` demonstrates creating an `openssl ca -config` config that points to `CA/ca.db.index` and `CA/ca.db.serial` and calls `openssl ca -config <cfg> -infiles <csr>`.
- Revoke flow: `revoke-cert.sh` -> `scripts/revoke.sh` shows how the CA index is parsed and how `openssl ca -config <cfg> -revoke` is used.

What not to change without caution
- Never rename `CA/ca.key`, `CA/ca.crt`, `CA/ca.db.index`, or `CA/ca.db.serial` without updating all scripts that reference them.
- Avoid changing `openssl` invocation flags (hash algorithm, extensions) unless you understand the certificate constraints (pathlen, basicConstraints) — these are security-sensitive.

Testing tips for developers & agents
- Use `test-config.sh` as a pattern for generating config fragments. Create ephemeral directories and never run operations against real CA keys in `CA/` unless intentionally testing.
- When adding new scripts, ensure they follow the same directory creation and permission patterns and that they check for required files (e.g., `if [ ! -f "$CA/ca.key" ]`).

If you need more context or access
- Ask for sample CA state (sanitized) or a reproducible test environment. If the user wants changes that touch security-sensitive files, request explicit confirmation and a safe test target path.

End
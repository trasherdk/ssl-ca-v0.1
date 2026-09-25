# ssl-ca v0.1 findings

Read-only review of the scripts, tests, and docs. No code was changed for this pass.
Reviewed 23 Sep 2026.

Mark each point when you judge it:

- `[ ]` open
- `[x]` accept (should be fixed)
- `[~]` defer (real, later)
- `[-]` reject (intended, or not a problem)

OCSP, a web UI, a general audit log, and a CRL cron are already in `TODO.md` and are not repeated here.

## Summary

| Severity | Count |
| --- | --- |
| High | 6 |
| Medium | 9 |
| Low | 5 |

## High

- [x] **1. Sub-CA and end-entity private keys are stored unencrypted.** The root key is created with AES-256. Sub-CA, server, and user keys are created with `openssl genrsa` and no cipher, so a copy of the CA directory is enough to issue or impersonate. `REVIEW.md` describes this as proper private key protection. The sub-CA test passes `-passin` against that key, which does not show the key is encrypted. Evidence: `new-root-ca.sh:41` uses `-aes256`. `new-sub-ca.sh:64`, `new-server-cert.sh:47`, and `new-user-cert.sh:47` do not. `test/test-sub-ca.sh:222`.

  **Suggestion.** Encrypt the sub-CA, server, and user keys the same way the root key is already encrypted: `openssl genrsa -aes256`.

  `new-root-ca.sh` prompts for a passphrase and writes an encrypted PEM. `new-sub-ca.sh`, `new-server-cert.sh`, and `new-user-cert.sh` should pass `-aes256` on their `genrsa` lines too. Leave the passphrase in the OpenSSL prompt. Do not store it in `.env` or on the command line.

  Every later read of those keys will prompt as well: the CSR step, renewal, sub-CA signing, and PKCS#12 export. That matches the root CA. For non-interactive runs, reuse the pattern already in `gen-root-ca-crl.sh`: if `OPENSSL_PASSIN` or `CA_PASSPHRASE` is set, pass it as `-passin`; otherwise let OpenSSL ask.

  `test/test-sub-ca.sh` should stop treating `-passin` as proof of encryption. Assert that `openssl rsa -in CA/ca.key -noout` fails with no passphrase, and that the same command succeeds with the test passphrase. Do the same for a server key and a user key.

  Directory mode `700` stays as it is. Encryption is what still protects a copied tree.

  Implemented for issuing keys only. `new-sub-ca.sh` generates `CA/ca.key` with `-aes256`, and later reads of that key prompt, or use `OPENSSL_PASSIN` / `CA_PASSPHRASE` when set. `test-sub-ca.sh` refuses a sub-CA key that opens with no passphrase.

  Server and user keys stay unencrypted. Those files are what Apache and a mail client load, and a passphrase there stops an unattended restart. The root key and sub-CA keys are the ones that can issue certificates, so they keep the passphrase.

- [x] **2. `renew-sub-ca.sh` does not match the files `new-sub-ca.sh` writes.** Creation stores `CA/ca.key` and `CA/ca.crt`, then deletes the CSR config. Renewal looks for `CA/<name>.key` and `CA/<name>.crt`, then reads `config/<name>-sub-ca.conf`. It exits before signing. If those paths were aligned, it still always requests the `v3_sub_ca` extension, so a restricted sub-CA would lose `pathlen:0`, and it does not append the parent certificate the way creation does. Evidence: `new-sub-ca.sh` writes `CA/ca.key` and `CA/ca.crt` (lines 58 and 151) and deletes the config at line 183. `renew-sub-ca.sh` used to look for the other names and always requested `v3_sub_ca`.

  **Decision.** One OpenSSL config per CA is enough. `config/root-ca.conf` holds the profiles (`v3_ca`, `v3_sub_ca`, `v3_restricted_sub_ca`, and later the server and user profiles). A script selects the section with `-extensions`. A sub-CA keeps its own copy of that file because the paths point at its `CA/` directory. The only per-certificate fragment is the server subject alternative name list. `sign-server-cert.sh`, `sign-user-cert.sh`, and `scripts/revoke.sh` still write their own full configs; those can move into the one file later.

  Implemented. `renew-sub-ca.sh` reads `CA/ca.key` and `CA/ca.crt`, builds the request from the current certificate, and signs with `config/root-ca.conf`. A restricted sub-CA keeps `v3_restricted_sub_ca`; a normal one uses `v3_ca`. The parent certificate is appended, and the registry copy is updated. `test/test-sub-ca-renewal.sh` covers both.

- [x] **3. Server and user renewal leave the old certificate valid and can change its identity.** Both sign configs set `unique_subject = no`, and the renew scripts never revoke the certificate they replace. Two certificates for the same name stay valid until something publishes a CRL. Server renewal builds a new CSR with `openssl req -new -batch` from the on-disk config defaults, so the subject becomes those defaults rather than the subject of the live certificate. It then calls `sign-server-cert.sh` with only the common name, so any extra DNS SAN is omitted. The sign scripts still prompt before committing, because they do not pass `-batch`. Evidence: `sign-server-cert.sh:81`, `sign-user-cert.sh:75`, `renew-server-cert.sh`, `renew-user-cert.sh`. The SAN list is rebuilt from CLI arguments in `sign-server-cert.sh`.

  **Suggestion.** Build the renewal request from the current certificate with `openssl x509 -x509toreq`, so the subject stays. Read the DNS names already on a server certificate and pass those extra names to `sign-server-cert.sh`. Revoke the previous certificate in the CA index before signing the replacement. Set `SSL_CA_BATCH=1` for that signing call so renewal does not ask for confirmation. First-time signing still asks. Publishing the CRL so clients can see the revocation is point 4, not this change.

  Implemented. Renewal builds the request from the current certificate, so the subject stays. Server renewal passes the existing DNS names through to `sign-server-cert.sh`. The previous certificate is revoked in the CA index before the new one is signed. `SSL_CA_BATCH=1` makes that signing use `-batch`. Clients still need a published CRL before they can see the revocation; that remains point 4.

- [ ] **4. A successful revoke does not give clients a way to see it.** Issued certificates have no CRL distribution point. `revoke-cert.sh` updates the OpenSSL index and does not generate a CRL. There is no sub-CA CRL script. `gen-root-ca-crl.sh` does not check the `openssl` exit status; if a previous CRL file is still on disk, the script prints it and exits 0 after a failed generation. Relying parties that are not manually configured with a CRL will keep accepting revoked certificates. Evidence: `sign-server-cert.sh` `server_cert` section (lines 92-97) and `sign-user-cert.sh` `user_cert` section (lines 81-86) set EKU and basicConstraints only. `revoke-cert.sh` ends after `scripts/revoke.sh`. `gen-root-ca-crl.sh:37-43`.

  **Suggestion.** Each new certificate names the CRL of the CA that signed it, so a client can see whether that signer was revoked. Regenerate the signing CA's local CRL whenever a certificate is revoked, and make CRL generation fail when OpenSSL fails.

  Add `crlDistributionPoints = URI:${CRL_URL}` on the certificate being signed. `CRL_URL` comes from the signing CA's `.env` and is the URL where that CA's PEM is published. A server or user certificate signed by the root names the root CRL. A server or user certificate signed by a sub-CA names that sub-CA's CRL. A sub-CA certificate (`v3_ca` and `v3_restricted_sub_ca`) names the root CRL, so a client that finds the sub-CA revoked rejects every certificate that chains through it. The root certificate is the trust anchor and gets no distribution point. Certificates already issued gain the extension only when they are renewed. This change does not turn on `renew-root-ca-crl.sh --publish`.

  After `revoke-cert.sh` and `revoke_issued_cert` succeed, regenerate the CRL of the CA that performed the revoke. For the root, that is `gen-root-ca-crl.sh`, writing `CRL/root-ca.crl.pem`. The script writes a temporary file, replaces the real CRL only when `openssl ca -gencrl` exits 0, and exits non-zero otherwise. A leftover PEM from an earlier run is then left untouched and is not reported as a new CRL.

  A sub-CA runs the same generation against its own `CA/` and `config/root-ca.conf`, writing `crl/<name>.crl.pem`. Copying that script into the sub-CA directory belongs with point 5, which is what currently leaves `scripts/revoke.sh` behind.

- [ ] **5. A copied sub-CA cannot revoke, because the helper it sources is left behind.** `revoke-cert.sh` sources `scripts/revoke.sh` next to itself. `new-sub-ca.sh` copies `revoke-cert.sh` into the sub-CA directory and does not copy `scripts/revoke.sh`. The copy list also names `revoke-server-cert.sh` and `revoke-user-cert.sh`, which are not in the tree, and the copy loop skips missing files quietly. From a sub-CA directory, `revoke-cert.sh` fails at the source line. Evidence: `revoke-cert.sh:86`. `new-sub-ca.sh:186-204`.

- [ ] **6. PKCS#12 export verifies with `TEST_PASSPHRASE` after writing the file.** Export prompts for a password. Verification then opens the new `.p12` with `pass:${TEST_PASSPHRASE}`. The test suite exports that variable, so tests pass. An operator who does not set it gets a failed script after the `.p12` already exists. README and the Copilot instructions still tell the operator to run `./p12.sh`, which is not a script in this tree. The live scripts are `server-p12.sh` and `user-p12.sh`. Evidence: `server-p12.sh:44`, `user-p12.sh:46`, `test/test-p12-certs.sh:19-20`.

## Medium

- [ ] **7. Expiry mail does not follow the design described in the README.** The script reads an email from the certificate and then sends only to `EMAIL` from `.env`. Before it sends, it calls `curl` against `ifconfig.me` and requires reverse DNS for that address. The MX host it looks up is not the host it delivers to. `sendmail` is always invoked with `-v`. A non-zero `sendmail` status is reported as sent unless the output contains the text `*** Error code`. README and `REVIEW.md` describe per-certificate recipients and TLS SMTP with client-certificate authentication. The script sets `-oMtls=client` and does not configure a client certificate. Sourcing `.env` also executes whatever shell is in that file. Evidence: `check-expiry.sh:69-83` reads the certificate email. Lines 137-191 send to `EMAIL`. Line 160 calls `ifconfig.me`.

- [ ] **8. The sub-CA registry copy is stored one directory deeper than the expiry check reads.** `new-sub-ca.sh` sets the registry directory to `certs/sub-CAs/<name>`, then creates `certs/sub-CAs/<name>/<name>/` and stores `ca.crt` there. `test-sub-ca.sh` expects that nested path, so the suite locks the layout in. `check-expiry.sh` looks for `certs/sub-CAs/<name>/ca.crt`, misses it, and later finds the nested file with `find *.crt`. That copy is then treated as an end-entity certificate named `ca`, using the 30-day threshold instead of the sub-CA threshold. Evidence: `new-sub-ca.sh:31` and `:176-180`. `test/test-sub-ca.sh:311`. `check-expiry.sh:229-245`.

- [ ] **9. Revoke moves server directories only, and does not disable a revoked sub-CA.** `move_revoked_cert` looks for `certs/<CN>`. User material lives in `certs/users/<email>`, so a revoked user certificate stays in the active tree. A revoked sub-CA certificate stays in `sub-CAs/<name>/` with its private key, and that directory can keep issuing. `move-revoked-certs.sh` only captures a CN when another RDN follows it, because the regex requires a slash after the value. `revoke-cert.sh` uses a different CN pattern, so the two scripts disagree on the same index line. Evidence: `scripts/revoke.sh:10-16`. User path is `certs/users` in `new-user-cert.sh:36`. `move-revoked-certs.sh:23` uses `CN=(.*)/`. `revoke-cert.sh:46` uses `CN=([^/]+)`.

- [ ] **10. Root renewal prompts for a new subject and reports success even when OpenSSL fails.** `renew-root-ca.sh` runs `openssl req -new -x509` against the existing key. That prompts for a distinguished name again and overwrites `CA/ca.crt`. There is no status check; the script always prints that the certificate was renewed. An interrupted run can leave a partial `ca.crt`, and `new-root-ca.sh` then refuses to start because `ca.crt` already exists. Evidence: `renew-root-ca.sh:21-27`. `new-root-ca.sh:14-19` exits when `CA/ca.crt` is present. The self-sign in `new-root-ca.sh:138` also has no status check.

- [ ] **11. End-entity certificates omit keyUsage and are valid for about ten years.** Server certificates get extendedKeyUsage `serverAuth`, `clientAuth`, and the obsolete `msSGC` and `nsSGC` OIDs. They do not get keyUsage. User certificates get `clientAuth` and `emailProtection`, also without keyUsage. Both sign configs set `default_days` to 3650. For a private CA that lifetime is a local policy choice; TLS stacks that require `digitalSignature` or `keyEncipherment` will reject or warn on these certificates. Evidence: `sign-server-cert.sh:77` and `:92-96`. `sign-user-cert.sh:71` and `:81-86`. The same 3650-day lifetime is set in `new-root-ca.sh:33`.

- [ ] **12. The CA index type is rewritten from the last line, including after a failed sub-CA sign.** `update_ca_index_type` sets field 5 of the last index line to `server`, `user`, or `subca`. It does not check that the line is the certificate just issued. `new-sub-ca.sh` calls it immediately after `openssl ca` and does not test that command's status. A failed sign can retag the previous certificate. The sign scripts do check status before calling the helper. Evidence: `lib/helpers.sh:32-54`. `new-sub-ca.sh:155-160`. `sign-server-cert.sh:117-124` and `sign-user-cert.sh:91-98` check status first.

- [ ] **13. CRL publish is hardcoded to `root@mail` and can restart remote sendmail.** `renew-root-ca-crl.sh --publish` copies the CRL to `root@mail:/etc/mail/certs/root-ca.crl.pem`. `--restart` runs `/etc/rc.d/rc.sendmail restart` over SSH. Those values are constants in the script, not settings from `.env`. On a host that can SSH to a machine named `mail`, the flag publishes and restarts that service. Evidence: `renew-root-ca-crl.sh:15-18` and `:46-61`.

- [ ] **14. The expiry tests marked done are stale, and the runner never calls them.** `TODO.md` marks expiry testing complete. `run-tests.sh` does not include `test-check-expiry.sh` or `test-expiry.sh`. `test-check-expiry.sh` looks for `certs/test-server.crt` and the phrase `will expire`. Live paths are `certs/<name>/<name>.crt`, and `check-expiry.sh` reports days remaining. `test-expiry.sh` needs a live mail path. `test-sub-ca.sh` also requires every copied script and directory to be owned by `root`, so the same test fails for any other user. Evidence: `run-tests.sh:25-42`. `test/test-check-expiry.sh:33-35` and `:66-74`. `TODO.md` items 1 and 10. `test/test-sub-ca.sh:282-298`.

- [ ] **15. README, REVIEW, and the agent instructions describe a different CA than the scripts.** README says a restricted sub-CA has `CA:FALSE`. The extension in `new-sub-ca.sh` is `CA:true, pathlen:0`, and `test-sub-ca.sh` asserts `CA:TRUE`. README says pathlen is calculated from the parent certificate. The script picks one of two fixed extensions. README's testing section documents only `test-root-ca.sh`. `REVIEW.md` says client-certificate SMTP is implemented and cites `test-email.sh`, which is not in the tree. The Copilot instructions still name `p12.sh` and the `mail` command. Evidence: `README.md` lines 12, 43, 84, and 194-206. `new-sub-ca.sh:67-71` and `:140-141`. `test/test-sub-ca.sh:180-184`. `REVIEW.md` lines 24-29.

## Low

- [ ] **16. The SpamAssassin debug rules match every message and add headers to all of them.** The whitelist meta rule is scoped to the expiry notification. The debug rules match From and Subject with `/(.*)/` and use `add_header all`. Loaded in a live SpamAssassin config, they stamp every message with `SSL-CA-From` and `SSL-CA-Subject`. The whitelist score of `-7` is separate and only fires when the real headers match. Evidence: `spamassassin/ssl-ca.cf:4-6` for the whitelist, lines 23-27 for the unscoped debug rules.

- [ ] **17. The pre-commit hook allows this checkout and does not watch private-key paths.** The hook exits 0 when the repository path contains `/github/`. This tree is `/root/local/github/ssl-ca-v0.1`, so the hook never inspects commits here. The sensitive regex covers `CA/`, `config/`, `CRL/`, `scripts/`, and `sub-CAs/`. It does not cover `certs/`, `*.key`, or `*.p12`. It does block `scripts/`, which is source rather than CA state. The hook is also inactive until `core.hooksPath` is set. Evidence: `hooks/pre-commit:31-36` and `:46`. `hooks/INSTALL_HOOK.md`.

- [ ] **18. Almost every operational script continues after a failed OpenSSL command.** `set -euo pipefail` appears on `renew-root-ca-crl.sh` and on one CRL test. `new-root-ca.sh`, the sign scripts, `gen-root-ca-crl.sh`, and the renew scripts otherwise rely on a few explicit checks. A failed root self-sign can still leave `ca.crt` behind. A failed CRL generation can leave the previous PEM in place and look successful, as noted in point 4. Evidence: `renew-root-ca-crl.sh:6` and `test/test-renew-root-ca-crl.sh:10` set the option. `new-root-ca.sh:138`, `gen-root-ca-crl.sh:37`, and `renew-root-ca.sh:25` do not check status.

- [ ] **19. `pathlen:0` is enforced in the certificate; the script gate is a text search, and normal sub-CAs are unlimited.** A restricted sub-CA is blocked from creating another sub-CA by `grep` for the string `pathlen:0` in OpenSSL text output. The certificate extension is the control that actually stops a subordinate CA from chaining. A normal sub-CA is issued with `CA:true` and no pathlen, so its key can mint further CAs. That matches the two-type design. The grep will miss the restriction if a future OpenSSL prints the constraint differently. Evidence: `new-sub-ca.sh:17-22` for the grep. Lines 67-71 choose `v3_ca` or `v3_restricted_sub_ca`. Root extensions are in `new-root-ca.sh:108-124`.

- [ ] **20. `sign-server-cert.sh` uses bash arithmetic under a `/bin/sh` shebang.** The SAN loop uses `((CNT++))`. This host's `/bin/sh` is bash, so extra DNS names work here. On a system where `/bin/sh` is dash, that expression fails, `CNT` stays put, and additional subject alternative names are written with a broken index. `new-server-cert.sh` is already bash and has the same loop. Evidence: `sign-server-cert.sh` starts with `#!/bin/sh` and uses `((CNT++))` at line 110. `new-server-cert.sh:1` is bash and uses the same form at line 101.

## What already holds

Root keys are 4096-bit RSA with SHA-256. CA `basicConstraints` and `keyUsage` are marked critical, including `keyCertSign` and `cRLSign`. Restricted sub-CAs get `pathlen:0`, and `test-sub-ca.sh` checks that distinction.

`run-tests.sh` orders 13 scripts: root, server, user, both renewals, invalid CSR, revoke, malformed config, sub-CA, PKCS#12, sub-CA autonomy, then standalone CRL and chain tests. Those scripts were not re-executed for this review.

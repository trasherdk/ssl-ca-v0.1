Enable versioned pre-commit hook

This repository includes a versioned pre-commit hook at `hooks/pre-commit`. The hook
blocks commits that modify sensitive paths (`CA/`, `config/`, `CRL/`, `scripts/`, `sub-CAs/`) unless:

- the checkout is under a parent directory named `github` (e.g. `/root/local/github/...`), or
- the environment variable `ALLOW_LOCAL_COMMITS=1` is set, or
- the commit is run in a CI environment (the `CI` env var is set).

To enable the versioned hooks for your local copy (recommended), run:

```sh
git config core.hooksPath hooks
chmod +x hooks/pre-commit
```

Notes
- The hook is local enforcement and can be bypassed with `--no-verify` or by unsetting
  `core.hooksPath`. For stronger guarantees, consider server-side hooks on the remote.
- If you need to allow a one-off commit in this checkout, set the environment variable:
  ```sh
  ALLOW_LOCAL_COMMITS=1 git commit -m "..."
  ```

If you want a variant that only blocks edits to a specific list of files (instead of full
directories), open a PR with the desired pattern and we'll review it.

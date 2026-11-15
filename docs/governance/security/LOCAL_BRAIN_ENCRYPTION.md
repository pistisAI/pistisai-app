# Local brain encryption at rest

Desktop and mobile builds encrypt `local_brain.sqlite` with
**SQLCipher-compatible AES-256** via SQLite3MultipleCiphers (Drift /
`package:sqlite3` with `hooks.user_defines.sqlite3.source: sqlite3mc`).

Web builds use browser origin-scoped storage (Wasm / IndexedDB), not this
on-disk file. OS full-disk encryption (BitLocker, FileVault, LUKS) remains
recommended as defense in depth.

## Key sources

The passphrase is never stored in the repository or in app config files.

| Priority | Source | How |
| --- | --- | --- |
| 1 | Environment | Set `PISTISAI_LOCAL_BRAIN_KEY` to a secret passphrase before starting the app |
| 2 | OS keystore | `flutter_secure_storage` (Keychain / Credential Manager / libsecret) under key `local_brain_encryption_key` |

If the environment variable is unset, the app reads or creates a random
32-byte key in the OS keystore. If the keystore is unavailable and no env
key is set, the database will not open (encrypting without a persisted key
would make the file unreadable after restart).

## Enable (end users)

1. Prefer turning on OS disk encryption for the whole volume.
2. Start Pistisai normally — encryption is on for native builds; the first
   launch creates a keystore-backed key automatically when possible.
3. Optional: set a managed passphrase for headless or CI-like installs:

   ```bash
   export PISTISAI_LOCAL_BRAIN_KEY='your-long-random-secret'
   ```

   Use the same value on every launch that should open that database file.
   Changing the key without a planned rekey makes the existing file unreadable.

## Verify encryption is active

### 1. Runtime (build / developer)

Native opens call `PRAGMA cipher = 'sqlcipher'` and `PRAGMA key = ...` before
any other SQL. If the bundled SQLite lacks MultipleCiphers, open fails with a
clear error instead of silently writing plaintext.

Unit coverage lives in `test/database/local_brain_encryption_test.dart`.

### 2. On-disk header check

An unencrypted SQLite file starts with the ASCII bytes `SQLite format 3`.
An encrypted `local_brain.sqlite` must **not**:

```bash
# Replace PATH with your application support directory for Pistisai.
# Linux example: $XDG_DATA_HOME/<app>/ or ~/.local/share/<app>/
head -c 16 PATH/local_brain.sqlite | od -An -tx1
# Encrypted: not 53 51 4c 69 74 65 20 66 6f 72 6d 61 74 20 33 00
# ("SQLite format 3\0")

# Or:
python3 - <<'PY'
from pathlib import Path
p = Path("PATH/local_brain.sqlite")
print(p.read_bytes()[:16])
print("plaintext" if p.read_bytes()[:16] == b"SQLite format 3\0" else "encrypted-or-empty")
PY
```

### 3. Existing plaintext databases

On upgrade, if `local_brain.sqlite` is still plaintext, the app migrates it
in place (VACUUM INTO + `PRAGMA rekey`) before opening. After a successful
migration the header check above should report encrypted.

## Developer notes

- Implementation: `lib/database/local_brain_encryption.dart`,
  `lib/database/local_brain_key_store.dart`,
  `lib/database/connection/native.dart`
- Do not commit passphrases, `.env` files with real keys, or keystore dumps
- Privacy wording: `docs/governance/legal/PRIVACY.md` and `web/privacy.html`

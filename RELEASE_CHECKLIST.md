# Release Checklist

Use this checklist before tagging a SyncVault release.

---

# 1. Source Review

- [ ] `README.md` is current.
- [ ] `PATCH_NOTES.md` is current.
- [ ] `docs/DISASTER_RECOVERY.md` is current.
- [ ] Inline comments in `user-data` are preserved.
- [ ] No generated temporary files are committed.
- [ ] No VM images, ISO files, logs, or firmware variable files are committed.

---

# 2. Secret Sanitization

Before publishing publicly, verify the repo does not contain real secrets.

Check for:

- [ ] real password hashes
- [ ] real SSH public keys, if not intended for publication
- [ ] real Restic passwords
- [ ] Backblaze B2 bucket names
- [ ] Backblaze B2 account IDs
- [ ] Backblaze B2 application keys
- [ ] private keys
- [ ] `.env` files
- [ ] local logs or shell history

Suggested commands:

```bash
grep -R "CHANGE_ME_RESTIC_PASSWORD" .
grep -R "CHANGE_ME" .
grep -R "B2_ACCOUNT" .
grep -R "ssh-ed25519" .
grep -R "BEGIN .*PRIVATE KEY" .
```

For public release, placeholders should be used:

```text
CHANGE_ME_PASSWORD_HASH
CHANGE_ME_SSH_PUBLIC_KEY
CHANGE_ME_RESTIC_PASSWORD
CHANGE_ME_B2_BUCKET
CHANGE_ME_B2_ACCOUNT_ID
CHANGE_ME_B2_ACCOUNT_KEY
```

---

# 3. Fresh Install Test

From a clean VM disk:

- [ ] Serve `user-data` and `meta-data` over HTTP.
- [ ] Boot Ubuntu Server ISO.
- [ ] Add kernel argument:

```text
autoinstall 'ds=nocloud-net;s=http://10.0.2.2:8000/'
```

- [ ] Confirm installation completes without manual intervention.
- [ ] Confirm `cloud-final.service` succeeds:

```bash
sudo systemctl status cloud-final.service --no-pager
```

- [ ] Confirm there are no fatal cloud-init errors:

```bash
sudo grep -iE 'fatal|traceback|failed|error' /var/log/cloud-init-output.log
```

---

# 4. Core Validation

Run:

```bash
sudo validate-syncvault-health
echo $?
```

Expected:

```text
SYNCVAULT HEALTH VALIDATION PASSED
0
```

Run:

```bash
sudo validate-syncvault-deep
echo $?
```

Expected:

```text
SYNCVAULT ALL VALIDATION PASSED
0
```

---

# 5. Individual Validators

Run each validator directly when debugging or before release.

```bash
sudo validate-network-security
sudo validate-zfs-scrubs
sudo check-zfs-health
sudo check-zfs-capacity
sudo check-sanoid-freshness
sudo check-restic-local
sudo validate-syncvault
```

Expected: each command exits `0`.

---

# 6. Timers

Verify scheduled maintenance timers:

```bash
systemctl list-timers 'validate-syncvault-*' --no-pager
systemctl list-timers 'zfs-scrub-*' --no-pager
systemctl list-timers 'check-*' --no-pager
systemctl list-timers 'restic-backup-*' --no-pager
```

Expected:

- [ ] daily fast health validation is scheduled
- [ ] weekly deep validation is scheduled
- [ ] monthly ZFS scrubs are scheduled
- [ ] local Restic backup is scheduled
- [ ] local Restic health check is scheduled

---

# 7. Syncthing GUI

Confirm GUI is local-only:

```bash
sudo ss -tlnp | grep 8384
```

Expected:

```text
127.0.0.1:8384
```

Tunnel from host:

```bash
ssh -L 8386:127.0.0.1:8384 -p 2222 redacted@localhost
```

Open:

```text
http://127.0.0.1:8386
```

---

# 8. Optional Backblaze B2 Validation

Only run this if B2 is configured.

- [ ] B2 bucket exists.
- [ ] B2 bucket is private.
- [ ] Object Lock is enabled if using immutable retention.
- [ ] Default retention policy is configured if desired.
- [ ] `/etc/restic/b2.env` has no placeholders.

Enable:

```bash
sudo enable-restic-b2
```

Validate:

```bash
sudo validate-restic-b2
echo $?
```

Expected:

```text
B2 VALIDATION PASSED
0
```

---

# 9. Disaster Recovery Drill

At least once before v1.0.0:

- [ ] restore from local Restic
- [ ] verify restored file contents
- [ ] inspect ZFS snapshot restore path
- [ ] review `docs/DISASTER_RECOVERY.md`
- [ ] confirm host-destroyed recovery steps are understandable

---

# 10. Release Tag

After all checks pass:

```bash
git status
git add .
git commit -m "Prepare v1.0.0"
git tag -a v1.0.0 -m "SyncVault v1.0.0"
```

Push:

```bash
git push
git push --tags
```

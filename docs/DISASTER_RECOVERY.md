# Disaster Recovery Runbook

This runbook documents common recovery scenarios for SyncVault.

The goal is to make restores boring, repeatable, and testable.

---

# Principles

SyncVault has several recovery layers:

```text
ZFS snapshots
local Restic
Backblaze B2 Restic
```

Use the fastest safe recovery layer first.

| Scenario | Preferred Recovery |
|---|---|
| accidental file deletion | ZFS snapshot |
| bad Syncthing sync | ZFS snapshot |
| local file corruption | ZFS snapshot or local Restic |
| destroyed local Restic repo | B2 Restic |
| destroyed host | reinstall + B2 restore |
| ransomware/root compromise | B2 Object Lock, if configured |

---

# Scenario 1: Recover a Deleted File from ZFS Snapshot

List snapshots:

```bash
ls /srv/syncthing/.zfs/snapshot
```

Find the file:

```bash
sudo find /srv/syncthing/.zfs/snapshot -name "filename"
```

Restore by copying it out:

```bash
sudo cp /srv/syncthing/.zfs/snapshot/<snapshot>/sync/path/to/file /srv/syncthing/sync/path/to/file
sudo chown redacted:redacted /srv/syncthing/sync/path/to/file
```

---

# Scenario 2: Restore from Local Restic

List snapshots:

```bash
sudo sh -c '. /etc/restic/local.env && restic snapshots'
```

Restore latest snapshot:

```bash
sudo mkdir -p /tmp/restore-local

sudo sh -c '. /etc/restic/local.env && \
  restic restore latest --target /tmp/restore-local'
```

Inspect restored files:

```bash
sudo find /tmp/restore-local/srv/syncthing
```

Copy back only what you need.

---

# Scenario 3: Restore from Backblaze B2

Confirm B2 credentials:

```bash
sudo grep -v 'KEY' /etc/restic/b2.env
```

List snapshots:

```bash
sudo sh -c '. /etc/restic/b2.env && restic snapshots'
```

Restore latest snapshot:

```bash
sudo mkdir -p /tmp/restore-b2

sudo sh -c '. /etc/restic/b2.env && \
  restic restore latest --target /tmp/restore-b2'
```

Inspect:

```bash
sudo find /tmp/restore-b2/srv/syncthing
```

---

# Scenario 4: Host Destroyed, Rebuild from Scratch

1. Boot new machine or VM with the SyncVault autoinstall.
2. Replace secrets in `user-data`.
3. Install using the documented HTTP autoinstall workflow.
4. SSH into the rebuilt host.
5. Configure `/etc/restic/b2.env`.
6. Restore from B2:

```bash
sudo mkdir -p /tmp/restore-b2

sudo sh -c '. /etc/restic/b2.env && \
  restic restore latest --target /tmp/restore-b2'
```

7. Copy restored Syncthing data into place:

```bash
sudo rsync -aHAX /tmp/restore-b2/srv/syncthing/ /srv/syncthing/
sudo chown -R redacted:redacted /srv/syncthing
```

8. Validate:

```bash
sudo validate-syncvault-all
```

---

# Scenario 5: Bad Syncthing Delete Propagated

Stop Syncthing:

```bash
sudo systemctl stop syncthing@redacted
```

Recover from snapshot or Restic.

Restart Syncthing:

```bash
sudo systemctl start syncthing@redacted
```

Open the GUI and verify device/folder state.

---

# Scenario 6: Pool Health Problem

Check status:

```bash
zpool status
```

Run validation:

```bash
sudo validate-zfs-scrubs
sudo check-zfs-health
```

If using bare metal with redundant disks, replace failing disks according to the relevant ZFS replacement procedure.

For a single-disk VM, a pool error generally means restoring from backup onto a new disk/image.

---

# Routine Recovery Drill

At least monthly:

```bash
sudo validate-syncvault-all
```

If B2 is configured:

```bash
sudo validate-restic-b2
```

The project is not considered healthy unless restore validation succeeds.

# SyncVault

A reproducible Ubuntu Server appliance for secure self-hosted synchronization, snapshotting, and backup.

SyncVault combines:

- Ubuntu Server 24.04 LTS autoinstall
- ZFS root filesystem
- Dedicated ZFS datasets for synchronized data and backup storage
- Syncthing for peer-to-peer file synchronization
- Sanoid for automatic ZFS snapshots
- Restic for local and offsite backups
- Backblaze B2 support for offsite disaster recovery
- Backblaze B2 Object Lock-aware backup behavior
- UFW firewall hardening
- Fail2ban intrusion protection
- SSH hardening and key-only authentication
- Fully automated cloud-init deployment
- Deterministic validation and restore testing scripts

The goal is to provide a:

- reproducible
- testable
- auditable
- self-healing
- infrastructure-as-code

backup and synchronization appliance.

---

# Features

## Operating System

- Ubuntu Server 24.04 LTS
- Minimal installation profile
- Fully unattended autoinstall
- Cloud-init based provisioning
- QEMU/KVM compatible
- HTTP-served autoinstall support

## Storage

- Native ZFS root install
- Compression enabled (`zstd`)
- Optimized datasets for synchronization workloads
- Dedicated datasets:
  - `rpool/sync`
  - `rpool/restic`
- Snapshot browsing via `.zfs/snapshot`

## Synchronization

- Syncthing
- Dedicated ZFS-backed sync dataset
- GUI bound to localhost only
- SSH tunnel access supported
- Firewall rules preconfigured

## Snapshotting

- Sanoid automatic snapshot management
- Frequent/hourly/daily/monthly retention
- Automatic pruning
- Explicit validation snapshots

## ZFS Scrubs

- Monthly scheduled ZFS scrub for `rpool`
- Monthly scheduled ZFS scrub for `bpool` when present
- Randomized timer delay to avoid predictable IO spikes
- Pool health and scrub schedule validation

## Backup

### Local

- Restic local repository
- Automated scheduled backups
- Restore validation testing
- Repository integrity checks
- Retention and pruning enabled locally

### Offsite

- Optional Backblaze B2 support
- Independent backup schedule
- Independent validation tooling
- Disaster recovery ready
- Object Lock-aware append-oriented B2 backup behavior

## Security

- UFW enabled by default
- Default deny inbound policy
- Fail2ban SSH protection
- Root login disabled
- Password SSH authentication disabled
- Public-key authentication only
- Hardened SSH daemon configuration
- Syncthing GUI bound to localhost only

## Validation

Automated validators verify:

- ZFS datasets
- Snapshot functionality
- Snapshot visibility
- Restic backups
- Restic restores
- Repository integrity
- UFW rules
- SSH hardening
- Fail2ban operation
- Syncthing localhost-only GUI exposure
- Backblaze B2 repository connectivity and restore behavior

---

# Architecture

## Storage Layout

```text
rpool/
├── ROOT/
├── USERDATA/
├── sync        -> /srv/syncthing
└── restic      -> /srv/restic
```

## Syncthing Layout

The ZFS dataset is mounted at:

```text
/srv/syncthing
```

The default Syncthing folder root is:

```text
/srv/syncthing/sync
```

This keeps the dataset mountpoint clean while placing actual synchronized data under a clear subdirectory.

## Restic Architecture

Two explicit repositories are supported.

### Local Repository

```text
/etc/restic/local.env
```

Backs up to:

```text
/srv/restic
```

### Backblaze B2 Repository

```text
/etc/restic/b2.env
```

Backs up to:

```text
b2:<bucket>:backup01
```

There is intentionally no ambiguous `restic.env` “active repository” alias.

Each repository has:

- independent environment configuration
- independent backup script
- independent systemd service
- independent systemd timer
- independent validation workflow

---

# 3-2-1-1-0 Backup Model

SyncVault is designed around the 3-2-1-1-0 backup rule:

```text
3 copies of data
2 different storage systems/media
1 offsite copy
1 immutable or offline copy
0 unverified backups
```

## How SyncVault Maps

| Rule | SyncVault Component | Status |
|---|---|---|
| 3 copies | live Syncthing data + local Restic + B2 Restic | satisfied once B2 is enabled |
| 2 media/types | ZFS live dataset + Restic repository format | satisfied logically |
| 1 offsite | Backblaze B2 | satisfied once B2 is enabled |
| 1 immutable/offline | ZFS snapshots + B2 Object Lock | partial locally, stronger with B2 Object Lock |
| 0 unverified | validation scripts and restore tests | satisfied when validators pass |

## Important Immutability Note

ZFS snapshots are immutable in the sense that snapshot contents cannot be modified after creation.

However, local root can still delete snapshots.

For strict ransomware-resistant immutability, use an offsite repository with Object Lock or another WORM/retention-protected storage target.

---

# Backblaze B2 Object Lock Model

Backblaze B2 Object Lock must be configured on the bucket side.

This VM cannot safely “turn on” Object Lock after the fact for an existing non-Object-Lock bucket.

Recommended B2 bucket policy:

- private bucket
- Object Lock enabled at bucket creation time
- default bucket retention enabled
- suggested initial retention: 30 days
- application key scoped to the bucket

## Why B2 Backups Are Append-Oriented

The B2 backup script intentionally does not run:

```bash
restic forget --prune
```

against the B2 repository.

Reason:

Object Lock can prevent deletion of old Restic pack/index/lock files during the retention window. Running prune against a retention-locked bucket can create confusing or failing behavior.

The intended model is:

```text
Local Restic repo:
  backup + forget + prune

B2 Object Lock repo:
  append-oriented backup + restore validation + check
```

Local storage handles normal pruning and space management.

B2 handles offsite encrypted recovery and immutability.

---

# Repository Layout

```text
.
├── README.md
├── user-data
├── meta-data
├── PATCH_NOTES.md
└── validation/
```

Important generated files on the installed system:

```text
/etc/restic/local.env
/etc/restic/b2.env
/etc/restic/b2-object-lock-policy.txt
/usr/local/sbin/restic-backup-local
/usr/local/sbin/restic-backup-b2
/usr/local/sbin/enable-restic-b2
/usr/local/sbin/validate-syncvault
/usr/local/sbin/validate-restic-b2
/usr/local/sbin/validate-zfs-scrubs
/usr/local/sbin/validate-network-security
```

---

# Requirements

## Host System

Recommended:

- Linux host
- QEMU/KVM
- 8 GB RAM minimum
- SSD storage recommended
- CPU virtualization support

## Packages

Example Debian/Ubuntu host:

```bash
sudo apt install qemu-kvm ovmf cloud-image-utils python3
```

---

# Ubuntu ISO

Recommended:

```text
Ubuntu Server 24.04 LTS
```

Recommended variant:

```text
ubuntu-24.04-live-server-amd64.iso
```

Why 24.04:

- mature ZFS support
- long-term support lifecycle
- stable cloud-init behavior
- stable autoinstall behavior
- modern kernel
- stable systemd behavior
- current Syncthing/Restic compatibility

---

# Preparing Autoinstall Files

## Required Files

```text
user-data
meta-data
```

## Generate Password Hash

```bash
mkpasswd --method=SHA-512
```

Replace:

```text
CHANGE_ME_PASSWORD_HASH
```

## SSH Public Key

Insert the full contents of:

```text
~/.ssh/id_ed25519.pub
```

Example:

```text
ssh-ed25519 AAAAC3... user@host
```

Do not insert only the fingerprint.

---

# Running HTTP Autoinstall

## Start HTTP Server

In the directory containing:

```text
user-data
meta-data
```

run:

```bash
python3 -m http.server 8000
```

---

# QEMU Installation

## Create Disk

```bash
qemu-img create -f qcow2 syncvault.qcow2 100G
```

## Copy OVMF Variables File

```bash
cp /usr/share/OVMF/OVMF_VARS_4M.fd ./OVMF_VARS.fd
```

Only the variables file must be copied.

The CODE firmware file remains read-only and shared.

---

# Boot QEMU

Example:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 8192 \
  -cpu host \
  -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=./OVMF_VARS.fd \
  -drive file=syncvault.qcow2,format=qcow2 \
  -cdrom ubuntu-24.04-live-server-amd64.iso \
  -net nic -net user,hostfwd=tcp::2222-:22
```

---

# Kernel Boot Parameters

At the GRUB screen, edit the Linux kernel line.

Find:

```text
linux /casper/vmlinuz ---
```

Change to:

```text
linux /casper/vmlinuz autoinstall 'ds=nocloud-net;s=http://10.0.2.2:8000/' ---
```

The single quotes are important.

Without them, the installer may ignore the datasource configuration because the semicolon can be interpreted specially by the bootloader.

---

# SSH Access

Example:

```bash
ssh -p 2222 redacted@localhost
```

---

# Syncthing GUI Tunnel

The Syncthing GUI intentionally binds only to localhost.

Create a tunnel:

```bash
ssh -L 8386:127.0.0.1:8384 -p 2222 redacted@localhost
```

Open:

```text
http://127.0.0.1:8386
```

---

# Automatic Services

## Enabled Automatically

- SSH
- UFW
- Fail2ban
- Syncthing
- Sanoid
- Local Restic timer

## Installed But Not Enabled Automatically

- Backblaze B2 backup timer

This is intentional.

The B2 repository requires credential configuration and bucket policy verification first.

---

# Backblaze B2 Setup

## 1. Create B2 Bucket

In Backblaze:

- create a private bucket
- enable Object Lock at bucket creation time
- configure default retention
- suggested initial retention: 30 days

## 2. Create Application Key

Create a scoped application key for this bucket.

Record:

```text
B2_ACCOUNT_ID
B2_ACCOUNT_KEY
B2_BUCKET
```

## 3. Configure VM

Edit:

```bash
sudo nano /etc/restic/b2.env
```

Replace:

```text
CHANGE_ME_B2_BUCKET
CHANGE_ME_B2_ACCOUNT_ID
CHANGE_ME_B2_ACCOUNT_KEY
```

## 4. Enable B2

```bash
sudo enable-restic-b2
```

## 5. Validate B2

```bash
sudo validate-restic-b2
```

---

# Validation

## ZFS Scrub Validation

```bash
sudo validate-zfs-scrubs
```

Validates:

- `rpool` exists and is healthy
- `bpool` exists and is healthy when present
- scrub timers are enabled and active
- current timer schedule
- last scrub/scan status

This validator does not start a scrub automatically because scrubs can be IO intensive.

To manually start scrubs:

```bash
sudo zpool scrub rpool
sudo zpool scrub bpool
```

## Local Infrastructure Validation

```bash
sudo validate-syncvault
```

Validates:

- ZFS datasets
- explicit ZFS validation snapshot
- snapshot visibility
- local Restic backup
- local Restic restore
- local Restic repository integrity

## Network Security Validation

```bash
sudo validate-network-security
```

Validates:

- SSH hardening
- UFW configuration
- Fail2ban status
- Syncthing GUI exposure
- listening ports

## Backblaze B2 Validation

```bash
sudo validate-restic-b2
```

Validates:

- B2 repository connectivity
- B2 backup creation
- B2 restore functionality
- B2 repository integrity

---

# Restic Timers

## Local Backup

```text
zfs-scrub-rpool.timer
zfs-scrub-bpool.timer
```

Default schedule:

```text
monthly, with randomized delay
```

## Local Backup

```text
restic-backup-local.timer
```

Default schedule:

```text
03:30 daily
```

## Backblaze B2 Backup

```text
restic-backup-b2.timer
```

Default schedule:

```text
04:30 daily
```

B2 timer is enabled only after:

```bash
sudo enable-restic-b2
```

---

# Security Posture

## SSH

Configured:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
X11Forwarding no
MaxAuthTries 3
```

## UFW

Default:

```text
deny incoming
allow outgoing
```

Allowed ports:

```text
22/tcp
22000/tcp
22000/udp
21027/udp
```

## Fail2ban

Configured for SSH intrusion protection.

---

# Restore Workflows

## Local Restore

```bash
sudo sh -c '. /etc/restic/local.env && \
  restic restore latest --target /tmp/restore'
```

## B2 Restore

```bash
sudo sh -c '. /etc/restic/b2.env && \
  restic restore latest --target /tmp/restore'
```

---

# Snapshot Browsing

Browse snapshots directly:

```bash
ls /srv/syncthing/.zfs/snapshot
```

Access specific snapshots:

```bash
/srv/syncthing/.zfs/snapshot/<snapshot-name>
```

---

# Operational Model

SyncVault intentionally separates:

```text
live sync
+
local snapshots
+
scheduled ZFS scrubs
+
local backups
+
offsite backups
```

This provides layered recovery:

| Failure Type | Recovery Layer |
|---|---|
| accidental deletion | ZFS snapshot |
| latent corruption detection | ZFS scrub |
| sync corruption | ZFS snapshot |
| application/config corruption | local Restic |
| local disk failure | B2 Restic |
| host loss | B2 Restic |
| ransomware/root compromise | B2 Object Lock, if configured correctly |

---

# Recommended Future Enhancements

Potential future improvements:

- encrypted ZFS datasets
- TPM-backed key storage
- scrub alerting/reporting
- SMART monitoring
- Grafana/Prometheus metrics
- email alerting
- healthcheck automation
- immutable backup retention tuning
- remote ZFS replication
- multi-node synchronization
- Docker/Podman support
- Kubernetes deployment profile
- bare-metal deployment profile
- UPS integration
- documented disaster recovery drills

---

# Known Limitations

- Syncthing is not a backup solution by itself
- Local Restic repository is not immutable
- Local ZFS snapshots can be deleted by root
- B2 Object Lock requires bucket-side configuration
- Backblaze credentials must be protected carefully
- QEMU user networking is intended primarily for testing
- Secure key management remains operator responsibility

---

# Philosophy

This project prioritizes:

- simplicity
- reproducibility
- auditability
- explicit configuration
- deterministic validation
- layered recovery
- operational clarity

Avoided intentionally:

- hidden magic
- ambiguous active repositories
- unnecessary orchestration layers
- opaque backup tooling
- confusing repository aliases

---

# Automated Maintenance Health Checks

SyncVault includes scheduled maintenance checks so failures are not discovered only during manual review.

## Timers

```text
check-restic-local.timer
check-zfs-health.timer
check-sanoid-freshness.timer
check-zfs-capacity.timer
validate-syncvault-all.timer
```

## Check Scripts

```text
/usr/local/sbin/check-restic-local
/usr/local/sbin/check-zfs-health
/usr/local/sbin/check-sanoid-freshness
/usr/local/sbin/check-zfs-capacity
/usr/local/sbin/validate-syncvault-all
```

## Aggregate Validation

Run:

```bash
sudo validate-syncvault-all
```

This runs:

- network security validation
- ZFS scrub schedule validation
- ZFS health validation
- ZFS capacity validation
- Sanoid snapshot freshness validation
- local Restic repository validation
- local backup/restore validation

B2 validation is intentionally separate because B2 is optional and may not be configured on every deployment:

```bash
sudo validate-restic-b2
```

---

# Disaster Recovery Documentation

See:

```text
docs/DISASTER_RECOVERY.md
```

This runbook covers:

- restoring a deleted file from ZFS snapshot
- restoring from local Restic
- restoring from Backblaze B2
- rebuilding after host destruction
- recovering from bad Syncthing propagation
- responding to ZFS pool health problems
- routine recovery drills


---

# v1.0-Clean Snapshot Freshness Behavior

`check-sanoid-freshness` is designed to behave cleanly on both mature systems and brand-new installs.

It now:

- fails if `rpool/sync` does not exist
- fails if no snapshots exist at all
- prefers Sanoid `autosnap_*` snapshots when present
- accepts `validation-*` snapshots on a fresh install before Sanoid has produced its first scheduled autosnap
- fails if the newest acceptable snapshot is older than the freshness threshold

Default freshness threshold:

```text
26 hours
```

This keeps the validator strict enough to detect broken snapshotting, while avoiding false failures immediately after a fresh install where validation snapshots exist but scheduled Sanoid snapshots have not yet run.


---

# Fast Health vs Deep Validation

SyncVault now separates routine health checks from full recovery drills.

## Fast Daily Health Check

Run:

```bash
sudo validate-syncvault-health
```

This is intended for frequent scheduled execution.

It checks:

- network security posture
- ZFS scrub scheduling
- ZFS pool health
- ZFS capacity
- Sanoid snapshot freshness
- local Restic repository metadata health

It intentionally does not perform a full restore drill.

## Deep Recovery Drill

Run:

```bash
sudo validate-syncvault-all
```

or:

```bash
sudo validate-syncvault-deep
```

This includes the fast checks plus a real local backup and restore validation.

This can be IO-heavy because it restores the latest Restic snapshot, which may be tens of GiB. It is suitable for:

- weekly or monthly recovery drills
- fresh image validation
- pre-release validation
- after major configuration changes

## Timers

```text
validate-syncvault-health.timer   daily fast validation
validate-syncvault-all.timer      weekly deep validation
```

B2 validation remains separate because B2 is optional:

```bash
sudo validate-restic-b2
```


---

# Backblaze B2 Validation Modes

Backblaze B2 validation is split into two modes.

## Fast B2 Validation

Run:

```bash
sudo validate-restic-b2
```

This is the default B2 validator.

It performs:

- B2 credential check
- repository initialization check
- append-oriented B2 backup
- snapshot listing
- restore of a small validation sentinel only
- `restic check`

This is designed to avoid exhausting Backblaze daily download caps during routine validation.

## Full B2 Disaster-Recovery Drill

Run:

```bash
sudo validate-restic-b2-full
```

This performs a full restore of the latest B2 snapshot.

It may:

- download many GiB
- take significant time
- trigger provider-side download limits
- incur bandwidth costs depending on the account/provider plan

Use this intentionally for periodic disaster-recovery drills, not routine daily checks.

## Recommended B2 Validation Cadence

| Validation | Command | Suggested Cadence |
|---|---|---|
| B2 fast validation | `sudo validate-restic-b2` | weekly or after changes |
| B2 full restore drill | `sudo validate-restic-b2-full` | monthly or quarterly |


---

# B2 Auto-Enable Behavior

The repo supports both safe public placeholders and private fully automated B2 deployment.

During first boot, `runcmd` checks:

```bash
/etc/restic/b2.env
```

If it still contains `CHANGE_ME`, B2 is skipped safely.

If real values are present, SyncVault automatically runs:

```bash
sudo enable-restic-b2
```

That initializes the B2 Restic repository if needed and enables:

```text
restic-backup-b2.timer
```

## Public repo behavior

Keep placeholders:

```text
CHANGE_ME_B2_BUCKET
CHANGE_ME_B2_ACCOUNT_ID
CHANGE_ME_B2_ACCOUNT_KEY
CHANGE_ME_RESTIC_PASSWORD
```

B2 will not auto-enable.

## Private deploy behavior

Replace placeholders with real private values before install.

B2 will auto-enable during first boot.


---

# Public Release Secret Hygiene

The public repository uses placeholders for deployment-specific secrets:

```text
CHANGE_ME_PASSWORD_HASH
CHANGE_ME_SSH_PUBLIC_KEY
CHANGE_ME_RESTIC_PASSWORD
CHANGE_ME_B2_BUCKET
CHANGE_ME_B2_ACCOUNT_ID
CHANGE_ME_B2_ACCOUNT_KEY
```

For a private deployment copy, replace these placeholders before serving `user-data`.

Do not commit real private deployment values to a public repository.

---

# Acknowledgements

Built using:

- Ubuntu
- cloud-init
- Syncthing
- ZFS
- Sanoid
- Restic
- Fail2ban
- UFW
- QEMU/KVM
- Backblaze B2

---

# License

MIT License

---

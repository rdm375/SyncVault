# Changelog

All notable changes to SyncVault will be documented in this file.

This project follows a simple release style:

- `v1.0.0-rcN` for release candidates
- `v1.0.0` for the first stable release
- future releases should summarize functional changes, validation changes, and migration notes

---

## v1.0.0-rc1

Initial release-candidate baseline.

### Added

- Ubuntu Server 24.04 LTS autoinstall profile.
- HTTP-served NoCloud autoinstall workflow.
- QEMU/KVM testing workflow.
- ZFS root installation.
- Dedicated ZFS datasets:
  - `rpool/sync` mounted at `/srv/syncthing`
  - `rpool/restic` mounted at `/srv/restic`
- Syncthing service configured for the operator user.
- Syncthing default folder suppression with `STNODEFAULTFOLDER=1`.
- Intended Syncthing folder root at `/srv/syncthing/sync`.
- Sanoid snapshot policy for `rpool/sync`.
- Scheduled ZFS scrub timers for:
  - `rpool`
  - `bpool`
- Local Restic repository support.
- Local Restic backup service and timer.
- Optional Backblaze B2 Restic repository support.
- B2 Object Lock-aware append-oriented backup behavior.
- SSH hardening:
  - root login disabled
  - password authentication disabled
  - public key authentication enabled
  - keyboard-interactive authentication disabled
  - X11 forwarding disabled
  - max auth tries limited
- UFW firewall baseline:
  - deny incoming
  - allow outgoing
  - OpenSSH allowed
  - Syncthing ports allowed
- Fail2ban SSH jail.
- Validation scripts:
  - `validate-network-security`
  - `validate-zfs-scrubs`
  - `check-zfs-health`
  - `check-zfs-capacity`
  - `check-sanoid-freshness`
  - `check-restic-local`
  - `validate-syncvault`
  - `validate-syncvault-health`
  - `validate-syncvault-all`
  - `validate-syncvault-deep`
  - `validate-restic-b2`
- Daily fast health validation timer.
- Weekly deep recovery validation timer.
- Disaster recovery runbook.
- Comprehensive GitHub README.

### Validation Status

The v1.0.0-rc1 baseline has been validated in QEMU with:

- network security validation passing
- ZFS scrub scheduling validation passing
- ZFS health validation passing
- ZFS capacity validation passing
- Sanoid freshness validation passing
- local Restic repository validation passing
- local backup and restore validation passing
- aggregate deep validation returning exit code `0`

### Known Limitations

- Backblaze B2 support is optional and requires external bucket/account configuration.
- B2 Object Lock must be configured in Backblaze; the VM cannot enable it retroactively.
- Local ZFS snapshots can still be deleted by root.
- Local Restic repository is not a disaster-recovery substitute for offsite backup.
- External alerting is not yet configured by default.
- QEMU user networking examples are primarily for testing.
- Secrets must be sanitized before publishing to a public repository.

---

## Unreleased

### Planned

- Optional external alerting integration.
- Optional SMART monitoring for bare-metal deployments.
- Optional LUKS support for secrets or removable media.
- Additional bare-metal recovery documentation.

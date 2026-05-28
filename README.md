# SyncVault

> Self-validating backup and disaster recovery appliance built with Syncthing, ZFS, Restic, and Ubuntu. SyncVault implements a practical 3-2-1-1-0 backup strategy as infrastructure-as-code.

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange)
![ZFS](https://img.shields.io/badge/ZFS-enabled-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-v1.0-success)

---

# Features

- Automated Ubuntu deployment
- Native ZFS storage
- Sanoid snapshot automation
- Syncthing replication
- Restic local and offsite backups
- Backblaze B2 support
- Immutable backup workflows
- Automated restore testing
- Continuous validation
- Hardened network security
- Infrastructure-as-code deployment

---

# 3-2-1-1-0 Backup Strategy

SyncVault is designed around the modern 3-2-1-1-0 backup rule:

| Requirement | SyncVault Implementation |
|---|---|
| 3 copies of data | live data + local Restic + optional B2 |
| 2 storage/media types | ZFS + Restic repositories |
| 1 offsite copy | Backblaze B2 |
| 1 immutable/offline copy | B2 Object Lock |
| 0 unverified backups | automated restore validation |

---

# Overview

SyncVault is a reproducible infrastructure-as-code backup VM that combines:

- Syncthing replication
- Sanoid-curated ZFS snapshots
- Restic backups
- Backblaze B2 offsite recovery
- automated restore testing
- hardened Ubuntu deployment
- continuous validation and integrity checks

into a single deployable system that can create a fully functional QEMU virtual machine in just a few minutes.

---

# Why SyncVault Exists

I originally built SyncVault because I wanted a dependable, decentralized way to curate and preserve my phone data.

Syncthing already solved synchronization beautifully, but combining it with ZFS datasets and Sanoid snapshots created a much stronger foundation for recovery and versioned storage.

Adding Restic enabled encrypted local and offsite backups, while scripted validation and restore testing made it possible to continuously verify the entire recovery chain.

The result became a practical implementation of the 3-2-1-1-0 backup strategy delivered as infrastructure-as-code.

---

# License

MIT License

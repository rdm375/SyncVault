# SyncVault

> Self-validating backup and disaster recovery appliance built with Syncthing, ZFS, Sanoid, Restic, and Ubuntu. SyncVault implements a practical 3-2-1-1-0 backup strategy as infrastructure-as-code.

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

I originally built SyncVault because I wanted a dependable, decentralized way to curate and preserve my phone user data.

Syncthing already solved real-time synchronization beautifully, but combining it with ZFS datasets and Sanoid snapshots created a much stronger foundation for recovery and versioned storage.

Adding Restic enabled encrypted local and offsite backups, while scripted validation and restore testing made it possible to continuously verify the entire recovery chain.

The result became a practical implementation of the 3-2-1-1-0 backup strategy delivered as infrastructure-as-code.

---

# QuickStart: Building, Running, and Validating SyncVault

This guide explains how to build, deploy, boot, and validate the SyncVault backup appliance.

---

# Requirements

## Host System

Recommended host environment:

* Linux host
* QEMU/KVM
* 2+ CPU cores
* 4 GB RAM minimum
* 64+ GB storage

---

# Required Software

Install:

```bash
sudo apt update

sudo apt install \
    qemu-system-x86 \
    qemu-utils \
    ovmf \
    cloud-image-utils \
    python3
```

---


---

# Download Ubuntu Server ISO

Download Ubuntu Server 24.04 LTS into project directory. In your project directory:

```text
wget https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso
```


---

# Repository Layout

After downloading the Ubuntu iso your project directory should at least contain the following:

```text
syncvault/
├── user-data
├── meta-data
└── ubuntu-24.04.3-live-server-amd64.iso
```


# Configure Autoinstall

Edit:

```text
user-data
```

Replace placeholders:

```text
CHANGE_ME_PASSWORD_HASH
CHANGE_ME_SSH_PUBLIC_KEY
CHANGE_ME_RESTIC_PASSWORD
CHANGE_ME_B2_BUCKET
CHANGE_ME_RESTIC_PASSWORD
CHANGE_ME_B2_ACCOUNT_ID
CHANGE_ME_B2_ACCOUNT_KEY
```

Note: You can/should change the username and hostname.

---

# Generate Password Hash

Generate SHA-512 password hash:

```bash
mkpasswd --method=SHA-512
```

Paste result into:

```yaml
identity:
  password: "YOUR_HASH"
```

---

# Add SSH Public Key

Insert your SSH public key into:

```yaml
ssh:
  authorized-keys:
    - "ssh-ed25519 AAAA..."
```

---

# Start Local HTTP Server

From the repository directory:

```bash
python3 -m http.server 8000
```

This serves:

* `user-data`
* `meta-data`

to cloud-init.

---

# Create Virtual Disk

Example:

```bash
qemu-img create -f qcow2 syncvault.qcow2 64G
```

---

# Copy over UEFI variables

```text
cp /usr/share/OVMF/OVMF_VARS_4M.fd .
```


# Boot the Installer

Example QEMU launch:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 2 \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.fd \
  -drive file=syncvault.qcow2,format=qcow2 \
  -cdrom ubuntu-24.04.3-live-server-amd64.iso \
  -net nic \
  -net user,hostfwd=tcp::2222-:22
```

---

# Start Ubuntu Autoinstall

At the GRUB menu:

Press:

```text
e
```

Find the Linux kernel line and append:

```text
autoinstall 'ds=nocloud-net;s=http://10.0.2.2:8000/'
```

Final line example:

```text
linux /casper/vmlinuz autoinstall 'ds=nocloud-net;s=http://10.0.2.2:8000/' ---
```

Then boot with:

```text
Ctrl+x
```

---

# Wait for Installation

The appliance will automatically:

* install Ubuntu
* configure ZFS
* configure Syncthing
* configure Restic
* configure Sanoid
* configure UFW
* configure Fail2ban
* configure validation tooling
* configure maintenance timers

Installation typically completes within several minutes.

---

# First Login

SSH into the VM:

```bash
ssh -p 2222 USER@127.0.0.1
```

---

# Verify Cloud-Init

On the VM, check installation completion:

```bash
sudo systemctl status cloud-final.service
```

Expected:

```text
Active: active (exited)
```

Then:

```bash
cloud-init status
```

Expected:

```text
status: done
```

or:

```text
status: disabled
```

Both are acceptable after successful provisioning.

---

# Validate the Appliance

## Fast Health Validation

On the VM, run:

```bash
sudo validate-syncvault-health
```

Checks include:

* ZFS health
* timers
* snapshot freshness
* repository metadata
* security posture
* capacity thresholds

Expected:

```text
SYNCVAULT HEALTH VALIDATION PASSED
```

---

# Deep Validation

On the VM, run full disaster recovery validation:

```bash
sudo validate-syncvault-deep
```

This performs:

* snapshot creation
* local Restic backup
* restore testing
* repository integrity verification

Expected:

```text
SYNCVAULT ALL VALIDATION PASSED
```

---

# Verify Scheduled Timers

On the VM, view validation timers:

```bash
systemctl list-timers 'validate-syncvault-*'
```

View scrub timers:

```bash
systemctl list-timers 'zfs-scrub-*'
```

Expected timers:

```text
validate-syncvault-health.timer
validate-syncvault-all.timer
zfs-scrub-rpool.timer
zfs-scrub-bpool.timer
```

---

# Verify Syncthing

On the VM, check service:

```bash
systemctl status syncthing@YOUR_USER
```

Verify GUI is localhost-only:

```bash
ss -lntp | grep 8384
```

Expected:

```text
127.0.0.1:8384
```

---

# Access Syncthing GUI

On the host, create SSH tunnel:

```bash
ssh -L 8386:127.0.0.1:8384 -p 2222 USER@127.0.0.1
```

Then on the host, open:

```text
http://127.0.0.1:8386
```

---

# Optional: Configure Backblaze B2

On the VM, edit:

```text
/etc/restic/b2.env
```

Example:

```bash
export RESTIC_REPOSITORY=b2:YOUR_BUCKET:backup01
export RESTIC_PASSWORD=CHANGE_ME_RESTIC_PASSWORD
export B2_ACCOUNT_ID=CHANGE_ME_B2_ACCOUNT_ID
export B2_ACCOUNT_KEY=CHANGE_ME_B2_ACCOUNT_KEY
```

---

# Enable B2 Backup

On the VM, run:

```bash
sudo enable-restic-b2
```

---

# Validate B2

On the VM, fast validation:

```bash
sudo validate-restic-b2
```

Full restore drill:

```bash
sudo validate-restic-b2-full
```

---

# Operational Philosophy

SyncVault is designed around continuous operational validation.

The appliance continuously verifies:

* backup creation
* restore capability
* repository integrity
* snapshot freshness
* ZFS health
* scrub scheduling
* security posture

The goal is not simply to create backups, but to continuously verify recoverability.

---

# Recommended Next Steps

After deployment:

* connect Syncthing peers
* configure backup retention policies
* configure Backblaze B2
* perform restore drills
* monitor validation timers
* commit infrastructure changes to Git

---

# Common Validation Commands

## ZFS Status

On the VM,
```bash
zpool status
zfs list
```

---

## Force Snapshots

On the VM,
```bash
sudo sanoid --take-snapshots
```

---

## View Restic Snapshots

On the VM,
```bash
sudo sh -c '. /etc/restic/local.env && restic snapshots'
```

---

## View Timers

On the VM,
```bash
systemctl list-timers
```

---

# License

MIT License


                              ---

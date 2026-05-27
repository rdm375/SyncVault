#!/usr/bin/env bash

# run on vm to make sure the services are functional

set -euo pipefail

SYNC_DATASET="rpool/sync"
RESTIC_DATASET="rpool/restic"
SYNC_ROOT="/srv/syncthing"
SYNC_FOLDER="/srv/syncthing/sync"
RESTIC_ENV="/etc/restic/restic.env"
RESTORE_DIR="/tmp/restic-restore-validation"
TEST_FILE="restic-validation-$(date +%Y%m%d-%H%M%S).txt"

echo "== SyncVault validation starting =="

echo
echo "== 1. Check ZFS datasets =="
zfs list "$SYNC_DATASET"
zfs list "$RESTIC_DATASET"

echo
echo "== 2. Check mountpoints =="
df -h "$SYNC_ROOT"
df -h /srv/restic

echo
echo "== 3. Check Syncthing folder =="
mkdir -p "$SYNC_FOLDER"
ls -ld "$SYNC_ROOT" "$SYNC_FOLDER"

echo
echo "== 4. Write test file into Syncthing folder =="
echo "restic validation $(date -Is)" > "$SYNC_FOLDER/$TEST_FILE"
cat "$SYNC_FOLDER/$TEST_FILE"

echo
echo "== 5. Take/verify Sanoid snapshot =="
sanoid --take-snapshots || true
zfs list -t snapshot "$SYNC_DATASET"

echo
echo "== 6. Verify file is visible in ZFS snapshot tree =="
LATEST_SNAP="$(ls -1 "$SYNC_ROOT/.zfs/snapshot" | sort | tail -1)"
echo "Latest snapshot: $LATEST_SNAP"
ls "$SYNC_ROOT/.zfs/snapshot/$LATEST_SNAP/sync" | grep "$TEST_FILE"

echo
echo "== 7. Run Restic backup =="
systemctl start restic-backup.service
systemctl status restic-backup.service --no-pager

echo
echo "== 8. List Restic snapshots =="
. "$RESTIC_ENV"
restic snapshots

echo
echo "== 9. Restore latest Restic snapshot =="
rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"
restic restore latest --target "$RESTORE_DIR"

echo
echo "== 10. Verify restored test file =="
RESTORED_FILE="$RESTORE_DIR$SYNC_FOLDER/$TEST_FILE"
cat "$RESTORED_FILE"

echo
echo "== 11. Restic repository integrity check =="
restic check

echo
echo "== VALIDATION PASSED =="
echo "Test file: $SYNC_FOLDER/$TEST_FILE"
echo "Restored file: $RESTORED_FILE"

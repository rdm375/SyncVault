#!/usr/bin/env bash


wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

qemu-img create -f qcow2 ubuntu-zfs.qcow2 100G

cp /usr/share/OVMF/OVMF_VARS_4M.fd .

# start webserver in project root to serve user-data.yaml and meta-data.yaml
python3 -m http.server 8000

qemu-system-x86_64 \
  -enable-kvm \
  -m 8192 \
  -smp 4 \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS_4M.fd \
  -drive file=ubuntu-zfs.qcow2,format=qcow2 \
  -cdrom ubuntu-24.04.3-live-server-amd64.iso \
  -boot d \
  -net nic \
  -net user,hostfwd=tcp::2222-:22
#
# 10.0.2.2 is a built-in QEMU NAT address that always points from the VM → host machine
#
# At the Ubuntu boot menu, press e, find the line starting with linux, and append this to the end:
# autoinstall 'ds=nocloud-net;s=http://10.0.2.2:8000/'
# ie, linux /casper/vmlinuz autoinstall 'ds=nocloud-net;s=http://10.0.2.2:8000/' ---
# press ctrl+x
#
# After install/reboot, SSH in:
# 
# ssh -p 2222 redacted@localhost
# 
# Then verify:
# 
# zfs list
# sudo ufw status
# sudo fail2ban-client status
# systemctl status syncthing@redacted
# systemctl status restic-backup.timer
#
# ssh tunnel for synthing gui:
# ssh -L 8386:127.0.0.1:8384 -p 2222 redacted@localhost
#

#!/bin/bash

. ../common.sh

sudo yum install qemu-kvm qemu-img edk2-ovmf

run_cmd "cp ../launch-qemu.sh /usr/local/bin"

# fix the path
sed -i 's|QEMU_INSTALL_DIR=/usr/local/bin/|QEMU_INSTALL_DIR="/usr/libexec/"|' /usr/local/bin/launch-qemu.sh
sed -i 's|UEFI_BIOS_CODE="/usr/local/share/qemu/OVMF_CODE.fd"|UEFI_BIOS_CODE=/usr/share/OVMF/OVMF_CODE.secboot.fd|' /usr/local/bin/launch-qemu.sh
sed -i 's|qemu-system-x86_64|qemu-kvm|' /usr/local/bin/launch-qemu.sh

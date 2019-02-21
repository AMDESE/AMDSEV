#!/bin/bash

. ../common.sh

run_cmd "cp ../launch-qemu.sh /usr/local/bin"

# fix the path
sed -i 's|QEMU_INSTALL_DIR=/usr/local/bin/|QEMU_INSTALL_DIR=""|' /usr/local/bin/launch-qemu.sh
sed -i 's|UEFI_BIOS_CODE="/usr/local/share/qemu/OVMF_CODE.fd"|UEFI_BIOS_CODE=/usr/share/edk2/ovmf/OVMF_CODE.fd|' /usr/local/bin/launch-qemu.sh

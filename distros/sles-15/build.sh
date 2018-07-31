#!/bin/bash

. ../common.sh

run_cmd "cp ../launch-qemu.sh /usr/local/bin"

# fix the path
sed -i 's|QEMU_INSTALL_DIR=/usr/local/bin/|QEMU_INSTALL_DIR=""|' /usr/local/bin/launch-qemu.sh
sed -i 's|UEFI_BIOS_CODE="/usr/local/share/qemu/OVMF_CODE.fd"|UEFI_BIOS_CODE=/usr/share/qemu/ovmf-x86_64-suse-4m.bin|' /usr/local/bin/launch-qemu.sh

# sles may have older version of patch, lets fix the sev-guest params
sed -i 's|reduced-phys-bits=1|reduced-phys-bits=5|' /usr/local/bin/launch-qemu.sh

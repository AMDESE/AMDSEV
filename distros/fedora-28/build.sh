#!/bin/bash

. ../common.sh

# install qemu and libvirt build depends
run_cmd "yum install yum-utils"
run_cmd "yum-builddep qemu"

# build and install QEMU 2.12
build_qemu "/usr/local"

run_cmd "cp ../launch-qemu.sh /usr/local/bin"

# fix path to pick rebuild BIOS
sed -i 's|UEFI_BIOS_CODE="/usr/local/share/qemu/OVMF_CODE.fd"|UEFI_BIOS_CODE=/usr/share/qemu//usr/share/OVMF/OVMF_CODE.secboot.fd|' /usr/local/bin/launch-qemu.sh

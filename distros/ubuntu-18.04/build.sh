#!/bin/bash

. ../common.sh

# build linux kernel image
run_cmd "apt-get -y build-dep linux-image-$(uname -r)"
run_cmd "apt-get -y install flex bison"
build_kernel

# install newly built kernel
install_kernel

# install qemu build deps
# build and install QEMU 2.12
run_cmd "apt-get -y build-dep qemu"
build_install_qemu "/usr/local"

run_cmd "apt-get -y build-dep ovmf"
build_install_ovmf "/usr/local/share/qemu"

run_cmd "cp ../launch-qemu.sh /usr/local/bin"

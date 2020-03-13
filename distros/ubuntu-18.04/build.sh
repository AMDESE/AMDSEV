#!/bin/bash

. ../common.sh

# host setup
SRC_LIST=/etc/apt/sources.list.d/amdsev.list
run_cmd "mkdir -p ${BUILD_DIR}"
grep deb-src /etc/apt/sources.list | grep -v "arch=amd64" | sudo tee ${SRC_LIST}
sudo sed -i -e "s/^\#\ *deb-src/deb-src/g" ${SRC_LIST}
run_cmd "sudo apt-get update"

# build linux kernel image
UNAME=$(ls /lib/modules | grep generic | head -1)
run_cmd "sudo apt-get -y build-dep linux-image-${UNAME}"
run_cmd "sudo apt-get -y install flex bison fakeroot bc kmod cpio libssl-dev libelf-dev"
build_kernel

# install newly built kernel
install_kernel

# install qemu build deps
# build and install QEMU 2.12
run_cmd "sudo apt-get -y build-dep qemu"
build_install_qemu "/usr/local"

run_cmd "sudo apt-get -y build-dep ovmf"
build_install_ovmf "/usr/local/share/qemu"

run_cmd "sudo cp ../launch-qemu.sh /usr/local/bin"
[ -f ${SRC_LIST} ] && run_cmd "sudo rm -f ${SRC_LIST}"

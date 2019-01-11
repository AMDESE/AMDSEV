#!/bin/bash

. ../common.sh

qemu_share=/usr/local/share/qemu

# Install additional tools
run_cmd "sudo apt-get -y install sudo curl systemd gnupg libelf-dev"

# install kata containers
install_kata
build_kata_kernel
build_install_kata_ovmf ${qemu_share}
build_install_kata_qemu
configure_kata_runtime

cat << EOM
***********************************************************************
Kata Containers are installed and configured to use AMD SEV!

As a test, start a busybox container like so:

   $ sudo docker run -it busybox sh

   / # dmesg | grep SEV
   [    0.001000] AMD Secure Encrypted Virtualization (SEV) active
   [    0.219196] SEV is active and system is using DMA bounce buffers

Enjoy!

EOM

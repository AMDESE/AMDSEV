#!/bin/bash

. ../common.sh

# Build/install the SEV kernel/BIOS/qemu
${BUILD_DIR}/../build.sh

# Install additional tools
run_cmd "apt-get install sudo curl systemd"

# Install Go 1.8.3+
run_cmd "apt-get install golang-1.8"
GOPATH=$HOME/go
PATH=$PATH:/usr/lib/go-1.8/bin:$GOPATH/bin

# install kata containers
install_kata
build_kata_kernel
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

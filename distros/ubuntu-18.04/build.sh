#!/bin/bash

. ../common.sh

grep deb-src /etc/apt/sources.list
if [ $? -ne 0 ]; then
cat >> /etc/apt/sources.list <<EOF
deb-src http://archive.ubuntu.com/ubuntu bionic main restricted
deb-src http://archive.ubuntu.com/ubuntu bionic-updates main restricted
deb-src http://archive.ubuntu.com/ubuntu bionic universe
deb-src http://archive.ubuntu.com/ubuntu bionic-updates universe
deb-src http://archive.ubuntu.com/ubuntu bionic multiverse
deb-src http://archive.ubuntu.com/ubuntu bionic-updates multiverse
deb-src http://archive.ubuntu.com/ubuntu bionic-backports main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu bionic-security main restricted
deb-src http://security.ubuntu.com/ubuntu bionic-security universe
deb-src http://security.ubuntu.com/ubuntu bionic-security multiverse
EOF
fi

# build linux kernel image
run_cmd "apt-get update"
run_cmd "apt install -y apt-utils"
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
run_cmd "apt-get -y build-dep linux-image-$(uname -r)"
run_cmd "apt-get -y install flex"
run_cmd "apt-get -y install bison fakeroot libssl-dev"
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
